package Plugins::QueueConsume::Settings;

use strict;
use warnings;

use base qw(Slim::Web::Settings);

use Slim::Utils::Prefs;

my $prefs = preferences('plugin.queueconsume');

sub name {
	return 'PLUGIN_QUEUECONSUME';
}


sub page {
	return 'plugins/QueueConsume/settings/basic.html';
}

sub prefs {
	return ($prefs, qw(consumeOnPrevious consumeLastTrack));
}

1;
