package Plugins::QueueConsume::Plugin;

# Queue Consume for Lyrion Music Server
#
# Reproduces MPD's "consume" behaviour: a track leaves the play queue once it
# has finished playing or has been skipped with Next/Previous, but NOT when you
# jump directly to some other track in the queue.
#
# Enabled per player in Settings -> Player -> Queue Consume.

use strict;
use warnings;

use base qw(Slim::Plugin::Base);

use Scalar::Util qw(blessed);
use Time::HiRes ();

use Slim::Control::Request;
use Slim::Player::Playlist;
use Slim::Player::Source;
use Slim::Utils::Log;
use Slim::Utils::Prefs;
use Slim::Utils::Timers;

my $log = Slim::Utils::Log->addLogCategory({
	category     => 'plugin.queueconsume',
	defaultLevel => 'WARN',
	description  => 'PLUGIN_QUEUECONSUME',
});

my $prefs = preferences('plugin.queueconsume');

# Runtime state, keyed on the master player's id:
#   index    - queue position of the track we consider "currently playing"
#   url      - its url, used to re-locate it if the queue shifted under us
#   jump     - how we got to the current track: absolute | next | prev
#   busy     - re-entrancy guard while we delete something ourselves
my %state;

# Slim::Player::Playlist::track() on current LMS, song() on older builds.
my $TRACK_AT = Slim::Player::Playlist->can('track') || Slim::Player::Playlist->can('song');

sub getDisplayName { 'PLUGIN_QUEUECONSUME' }

sub initPlugin {
	my $class = shift;

	$prefs->init({
		consumeOnPrevious => 0,
		consumeLastTrack  => 1,
	});

	if (main::WEBUI) {
		require Plugins::QueueConsume::PlayerSettings;
		Plugins::QueueConsume::PlayerSettings->new();
	}

	Slim::Control::Request::subscribe(
		\&_playlistCallback,
		[ ['playlist'],
		  ['newsong', 'jump', 'index', 'stop', 'clear', 'load', 'loadtracks',
		   'play', 'open', 'addtracks', 'inserttracks', 'delete', 'move', 'sync'] ]
	);

	# A stop/pause/power/playlistcontrol issued by the user must not be mistaken
	# for "the queue ran out of tracks".
	Slim::Control::Request::subscribe(
		\&_transportCallback,
		[ ['stop', 'pause', 'power', 'playlistcontrol'] ]
	);

	# CLI / JSON-RPC:  <playerid> queueconsume <0|1>   and   <playerid> queueconsume ?
	Slim::Control::Request::addDispatch(['queueconsume', '_newvalue'], [1, 0, 0, \&_consumeCommand]);
	Slim::Control::Request::addDispatch(['queueconsume', '?'],         [1, 1, 0, \&_consumeQuery]);

	$class->SUPER::initPlugin(@_);
}

sub shutdownPlugin {
	Slim::Control::Request::unsubscribe(\&_playlistCallback);
	Slim::Control::Request::unsubscribe(\&_transportCallback);
	%state = ();
}

# ---------------------------------------------------------------- callbacks --

sub _playlistCallback {
	my $request = shift;

	my $client = $request->client() || return;
	$client = $client->master();

	my $cmd = $request->getRequest(1) || return;
	my $st  = $state{$client->id} ||= {};

	main::DEBUGLOG && $log->is_debug && $log->debug(
		$client->id . ": playlist notification cmd=$cmd"
	);

	if ($cmd eq 'jump' || $cmd eq 'index') {
		my $index = $request->getParam('_index');
		$index = '' unless defined $index;
		$index =~ s/^\s+//;

		if ($index =~ /^(?:\+|%2B)/i) {
			$st->{jump} = 'next';
		}
		elsif ($index =~ /^-/) {
			$st->{jump} = 'prev';
		}
		else {
			# an explicit queue position: the user picked a track, keep the old one
			$st->{jump} = 'absolute';
		}

		main::DEBUGLOG && $log->is_debug && $log->debug(
			$client->id . ": jump/index cmd, _index='$index', classified as '$st->{jump}'"
		);

		return;
	}

	if ($cmd eq 'newsong') {
		_songChanged($client);
		return;
	}

	if ($cmd eq 'stop') {
		_maybeConsumeLast($client);
		return;
	}

	# any other queue mutation: just refresh our idea of what is playing
	_sync($client);
}

sub _transportCallback {
	my $request = shift;

	my $client = $request->client() || return;
	$client = $client->master();

	# the user is driving, so cancel any pending end-of-queue consumption
	Slim::Utils::Timers::killTimers($client, \&_consumeLast);
}

# ------------------------------------------------------------------- logic --

sub _songChanged {
	my $client = shift;
	my $st = $state{$client->id} ||= {};

	return if $st->{busy};

	my $jump      = delete $st->{jump};
	my $prevIndex = $st->{index};
	my $prevUrl   = $st->{url};

	my $consume = 1;

	$consume = 0 unless defined $prevIndex;
	$consume = 0 unless $prefs->client($client)->get('consume');
	$consume = 0 if $jump && $jump eq 'absolute';
	$consume = 0 if $jump && $jump eq 'prev' && !$prefs->get('consumeOnPrevious');

	# repeat-one, or a restart of the same entry: never eat what is playing now
	my $nowIndex = Slim::Player::Source::playingSongIndex($client);
	my $sameIndexGuard = (defined $nowIndex && defined $prevIndex && $nowIndex == $prevIndex) ? 1 : 0;
	$consume = 0 if $sameIndexGuard;

	main::DEBUGLOG && $log->is_debug && $log->debug(
		$client->id . ": songChanged jump=" . (defined $jump ? $jump : 'undef')
		. " prevIndex=" . (defined $prevIndex ? $prevIndex : 'undef')
		. " nowIndex=" . (defined $nowIndex ? $nowIndex : 'undef')
		. " sameIndexGuard=$sameIndexGuard consume=$consume"
	);

	if ($consume) {
		main::INFOLOG && $log->is_info && $log->info(
			$client->id . ": consuming index $prevIndex (jump=" . ($jump || 'natural') . ")"
		);

		$st->{busy} = 1;
		_removeTrack($client, $prevIndex, $prevUrl);
		$st->{busy} = 0;
	}

	_sync($client);
}

# Playback stopped. If we were sitting on the last entry of the queue and the
# user did not press stop/pause, the queue ran out - consume that final track.
sub _maybeConsumeLast {
	my $client = shift;
	my $st = $state{$client->id} ||= {};

	return if $st->{busy};
	return unless $prefs->get('consumeLastTrack');
	return unless $prefs->client($client)->get('consume');
	return unless defined $st->{index};

	my $count = Slim::Player::Playlist::count($client) || 0;
	return unless $count && $st->{index} == $count - 1;

	# Deferred, so an explicit stop/pause notification arriving right after this
	# one still has a chance to cancel it.
	Slim::Utils::Timers::killTimers($client, \&_consumeLast);
	Slim::Utils::Timers::setTimer($client, Time::HiRes::time() + 0.5, \&_consumeLast);
}

sub _consumeLast {
	my $client = shift;
	my $st = $state{$client->id} || return;

	return if $st->{busy};
	return unless defined $st->{index};
	return if Slim::Player::Source::playmode($client) =~ /play/;

	my $count = Slim::Player::Playlist::count($client) || 0;
	return unless $count && $st->{index} == $count - 1;

	my ($index, $url) = ($st->{index}, $st->{url});
	delete $st->{index};
	delete $st->{url};

	main::INFOLOG && $log->is_info && $log->info($client->id . ": consuming final index $index");

	$st->{busy} = 1;
	_removeTrack($client, $index, $url, 1);
	$st->{busy} = 0;
}

sub _removeTrack {
	my ($client, $index, $url, $force) = @_;

	my $count = Slim::Player::Playlist::count($client) || 0;
	return unless $count;

	# the queue may have shifted since we recorded this position
	if (defined $url) {
		my $at = _urlAt($client, $index);
		if (!defined $at || $at ne $url) {
			$index = _findUrl($client, $url);
			return unless defined $index;
		}
	}

	return if !defined $index || $index < 0 || $index >= $count;

	unless ($force) {
		my $now = Slim::Player::Source::playingSongIndex($client);
		return if defined $now && $now == $index;
	}

	$client->execute(['playlist', 'delete', $index]);
}

sub _sync {
	my $client = shift;
	my $st = $state{$client->id} ||= {};

	my $count = Slim::Player::Playlist::count($client) || 0;
	my $index = $count ? Slim::Player::Source::playingSongIndex($client) : undef;

	if (defined $index && $index >= 0 && $index < $count) {
		$st->{index} = $index;
		$st->{url}   = _urlAt($client, $index);
	}
	else {
		delete $st->{index};
		delete $st->{url};
	}
}

sub _urlAt {
	my ($client, $index) = @_;

	return unless $TRACK_AT && defined $index;

	my $obj = eval { $TRACK_AT->($client, $index) };
	return unless defined $obj;

	return blessed($obj) ? $obj->url : "$obj";
}

sub _findUrl {
	my ($client, $url) = @_;

	my $count = Slim::Player::Playlist::count($client) || 0;

	for my $i (0 .. $count - 1) {
		my $at = _urlAt($client, $i);
		return $i if defined $at && $at eq $url;
	}

	return;
}

# ---------------------------------------------------------------------- CLI --

sub _consumeCommand {
	my $request = shift;

	if ($request->isNotCommand([['queueconsume']])) {
		$request->setStatusBadDispatch();
		return;
	}

	my $client = $request->client();
	if (!$client) {
		$request->setStatusBadDispatch();
		return;
	}
	$client = $client->master();

	my $cprefs   = $prefs->client($client);
	my $newvalue = $request->getParam('_newvalue');

	$newvalue = $cprefs->get('consume') ? 0 : 1 unless defined $newvalue;

	$cprefs->set('consume', $newvalue ? 1 : 0);
	_sync($client);

	$request->setStatusDone();
}

sub _consumeQuery {
	my $request = shift;

	if ($request->isNotQuery([['queueconsume']])) {
		$request->setStatusBadDispatch();
		return;
	}

	my $client = $request->client();
	if (!$client) {
		$request->setStatusBadDispatch();
		return;
	}

	$request->addResult('_queueconsume', $prefs->client($client->master)->get('consume') ? 1 : 0);
	$request->setStatusDone();
}

1;
