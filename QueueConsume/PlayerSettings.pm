package Plugins::QueueConsume::PlayerSettings;

# Per-player settings page (Settings -> Player -> <player> -> Extra Settings).
#
# Only the per-player enable flag lives here; the two global options are on
# Plugins::QueueConsume::Settings (server-wide page).

use strict;
use warnings;

use base qw(Slim::Web::Settings);

use Slim::Utils::Prefs;

my $prefs = preferences('plugin.queueconsume');

# needsClient() = 1 registers this under the player settings.
sub name        { 'PLUGIN_QUEUECONSUME' }
sub page        { 'plugins/QueueConsume/settings/player.html' }
sub needsClient { 1 }

sub validFor {
	my ($class, $client) = @_;
	return unless $client;
	return $client->isPlayer();
}

sub handler {
	my ($class, $client, $paramRef) = @_;

	my $cprefs = $prefs->client($client);

	if ($paramRef->{saveSettings}) {
		# Force a strict 1/0 flag so an empty form field is never stored as ''.
		$cprefs->set('consume', $paramRef->{pref_consume} ? 1 : 0);
	}

	# Populate the form with the current value.
	$paramRef->{prefs}{pref_consume} = $cprefs->get('consume') || 0;

	return $class->SUPER::handler($client, $paramRef);
}

1;
