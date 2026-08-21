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

	# If the user clicked "Save Settings" in the LMS Web UI
	if ($paramRef->{saveSettings}) {
		# Force a strict 1 or 0 binary flag. 
		# This guarantees that empty web form fields are never written as blank strings.
		$cprefs->set('consume', $paramRef->{pref_consume} ? 1 : 0);
		$prefs->set('consumeOnPrevious', $paramRef->{pref_consumeOnPrevious} ? 1 : 0);
		$prefs->set('consumeLastTrack',  $paramRef->{pref_consumeLastTrack}  ? 1 : 0);
	}

	# Read the parameters safely back to display in the Web UI
	# Using '|| 0' guarantees a default value is shown even if the prefs cache is cleared
	$paramRef->{prefs}{pref_consume}           = $cprefs->get('consume') || 0;
	$paramRef->{prefs}{pref_consumeOnPrevious} = $prefs->get('consumeOnPrevious') || 0;
	$paramRef->{prefs}{pref_consumeLastTrack}  = $prefs->get('consumeLastTrack') || 0;

	return $class->SUPER::handler($client, $paramRef);
}

1;
