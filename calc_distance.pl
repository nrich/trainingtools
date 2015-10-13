#!/usr/bin/perl 

use strict;
use warnings;

use constant MILES_CONVERSION => 1.609344;

main(@ARGV);

sub main {
    my ($time, $pace, $unit) = @_;

    $unit ||= 'km'; 

    my $seconds = to_seconds($time||0);
    my $pace_seconds = to_seconds($pace||0);
    my $cm = to_centimetres("1${unit}");

    my $distance = ($seconds/$pace_seconds) * $cm;

    my $km_traveled = $distance / 100_000;
    my $miles_traveled = $distance / (MILES_CONVERSION * 100_000);

    my $kmph = sprintf '%0.2f', (($distance/$seconds)/100_000) * 3600;
    my $mph = sprintf '%0.2f', $kmph/MILES_CONVERSION;
    my $mins_per_km = (60 / $kmph);
    my $mins_per_mile = sprintf '%0.2f', ($mins_per_km * MILES_CONVERSION);

    $mins_per_km = format_time_output(sprintf '%0.2f', $mins_per_km);
    $mins_per_mile = format_time_output($mins_per_mile);

    printf "%.2f km\n", $km_traveled;
    printf "%.2f miles\n", $miles_traveled;

    print "$kmph km/h\n";
    print "$mph miles/h\n";
    print "$mins_per_km minutes per km\n";
    print "$mins_per_mile minutes per mile\n";
}

sub format_time_output {
    my ($minutes) = @_;

    my ($min,  $sec) = split '\.', "$minutes";
    $sec = int($sec * 0.6);
    $sec = sprintf('%02d', $sec);

    return "$min:$sec";
}

sub to_seconds {
    my ($time) = @_;

    my ($hours, $minutes, $seconds) = (0, 0, 0);

    if ($time =~ /^(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s)?$/) {
        $hours = $1||0;
        $minutes = $2||0;
        $seconds = $3||0;
    } elsif ($time =~ /^(?:(\d+):)?(?:(\d\d):)?(?:(\d\d))?$/) {
        $hours = $1||0;
        $minutes = $2||0;
        $seconds = $3||0;
    } elsif ($time =~ /^(\d+)$/) {
        $seconds = $1;
    } else {
        $seconds = 0;
    }

    return ($hours * 3600) + ($minutes * 60) + $seconds;
}

sub to_centimetres {
    my ($distance) = @_;

    my ($km, $m, $cm) = (0, 0, 0);

    if ($distance =~ /^(?:(\d+(?:\.\d+)?)km)?(?:(\d+(?:\.\d+)?)m)?(?:(\d+)cm)?$/) {
        $km = $1||0;
        $m = $2||0;
        $cm = $3||0;
    } elsif ($distance =~ /^(\d+(\.\d+)?)miles?$/) {
        $km = $1 * MILES_CONVERSION;
    } else {
        $km = $distance;
    }

    return (100_000 * $km) + ($m * 100) + $cm;
}
