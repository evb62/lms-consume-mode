package Plugins::QueueConsume::PlayerSettings;

use strict;
use warnings;

use base qw(Slim::Web::Settings);

use Slim::Utils::Prefs;

my $prefs = preferences('plugin.queueconsume');

sub name {
	return 'PLUGIN_QUEUECONSUME';
}

sub page {
	return 'plugins/QueueConsume/settings/player.html';
}

sub needsClient { 1 }

sub validFor {
	my ($class, $client) = @_;
	return $client->isPlayer();
}

sub handler {
	my ($class, $client, $paramRef) = @_;

	my $cprefs = $prefs->client($client);

	if ($paramRef->{saveSettings}) {
		$cprefs->set('consume', $paramRef->{pref_consume} ? 1 : 0);
		$prefs->set('consumeOnPrevious', $paramRef->{pref_consumeOnPrevious} ? 1 : 0);
		$prefs->set('consumeLastTrack',  $paramRef->{pref_consumeLastTrack}  ? 1 : 0);
	}

	$paramRef->{pref_consume}           = $cprefs->get('consume');
	$paramRef->{pref_consumeOnPrevious} = $prefs->get('consumeOnPrevious');
	$paramRef->{pref_consumeLastTrack}  = $prefs->get('consumeLastTrack');

	return $class->SUPER::handler($client, $paramRef);
}

1;
