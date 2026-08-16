package Plugins::ConsumeMode::Settings;

use strict;
use warnings;

use base qw(Slim::Web::Settings);

use Slim::Utils::Prefs;

my $prefs = preferences('plugin.consumemode');

sub name {
	return Slim::Web::HTTP::CSRF->protectName('PLUGIN_CONSUMEMODE');
}

sub page {
	return Slim::Web::HTTP::CSRF->protectURI('plugins/ConsumeMode/settings/basic.html');
}

sub prefs {
	return ($prefs, qw(consumeOnPrevious consumeLastTrack));
}

1;
