package Plugins::QueueConsume::PlayerSettings;

use strict;
use warnings;

use base qw(Slim::Web::Settings);

use Slim::Utils::Prefs;

my $prefs = preferences('plugin.queueconsume');

sub name {
	return Slim::Web::HTTP::CSRF->protectName('PLUGIN_QUEUECONSUME');
}

sub page {
	return Slim::Web::HTTP::CSRF->protectURI('plugins/QueueConsume/settings/player.html');
}

sub needsClient { 1 }

sub validFor {
	my ($class, $client) = @_;
	return $client->isPlayer();
}

sub prefs {
	my ($class, $client) = @_;
	return ($prefs->client($client), qw(consume));
}

1;
