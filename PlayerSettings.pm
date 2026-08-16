package Plugins::ConsumeMode::PlayerSettings;

use strict;
use warnings;

use base qw(Slim::Web::Settings);

use Slim::Utils::Prefs;

my $prefs = preferences('plugin.consumemode');

sub name {
	return Slim::Web::HTTP::CSRF->protectName('PLUGIN_CONSUMEMODE');
}

sub page {
	return Slim::Web::HTTP::CSRF->protectURI('plugins/ConsumeMode/settings/player.html');
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
