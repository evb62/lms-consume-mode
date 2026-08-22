package Plugins::QueueConsume::Settings;

# Server-wide settings page for Queue Consume, opened via the "Settings"
# link in Manage Plugins (install.xml's <optionsURL>).
#
# Holds the two global options. The per-player enable flag lives on
# Plugins::QueueConsume::PlayerSettings instead.
#
# Preferences are read/written manually and exposed to the template as
# $paramRef->{prefs}{pref_*}; SUPER::handler() is called last purely for
# the page chrome (settings menu, template rendering).

use strict;
use warnings;

use base qw(Slim::Web::Settings);

use Slim::Utils::Prefs;

my $prefs = preferences('plugin.queueconsume');

# page is the URL below /plugins/... and must match the template path
# relative to HTML/EN (HTML/EN/plugins/QueueConsume/settings/basic.html).
# needsClient() = 0 makes this a server-wide page.
sub name        { 'PLUGIN_QUEUECONSUME' }
sub page        { 'plugins/QueueConsume/settings/basic.html' }
sub needsClient { 0 }

sub handler {
	my ($class, $client, $paramRef) = @_;

	if ($paramRef->{saveSettings}) {
		# Force strict 1/0 flags so empty form fields are never stored as ''.
		$prefs->set('consumeOnPrevious', $paramRef->{pref_consumeOnPrevious} ? 1 : 0);
		$prefs->set('consumeLastTrack',  $paramRef->{pref_consumeLastTrack}  ? 1 : 0);
	}

	# Populate the form with the current values.
	$paramRef->{prefs}{pref_consumeOnPrevious} = $prefs->get('consumeOnPrevious') || 0;
	$paramRef->{prefs}{pref_consumeLastTrack}  = $prefs->get('consumeLastTrack')  || 0;

	return $class->SUPER::handler($client, $paramRef);
}

1;
