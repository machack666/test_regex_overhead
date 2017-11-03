#!/usr/bin/perl

use strict;
use warnings;
use autodie;

my @target_versions = qw/5.8.8 5.10.0 5.14.3 5.22.2 5.24.2 5.26.1/;

install_missing_versions();
setup_scripts();
run_tests();


#################### Routines ####################

sub run_tests {
    for my $vers (@target_versions) {
        print "Version: $vers (Encode)\n";
        system("PLENV_VERSION=$vers time plenv exec perl with_encode.pl");
        print "Version: $vers (No Encode)\n";
        system("PLENV_VERSION=$vers time plenv exec perl without_encode.pl");
    }
}

sub setup_scripts {
    my @prog = <DATA>;

    open my $enc, '>', 'with_encode.pl';
    open my $noenc, '>', 'without_encode.pl';

    for (@prog) {
        print $enc $_;
        print $noenc $_ unless /Encode/;
    }
    close $enc;
    close $noenc;
}

sub install_missing_versions {
    my %existing_versions = get_perl_versions();
    my @missing = grep { !exists $existing_versions{$_} } @target_versions;
    for my $vers (@missing) {
        system("plenv install $vers");
    }
}

sub get_perl_versions {
    my @vers = qx(plenv versions --bare);
    chomp @vers;
    return ( map { $_ => $_ } @vers );
}


__DATA__
#!/usr/bin/perl -l
use strict;
use warnings;

use Encode;

my $big_string = "ABCDEFGHIJKLMNOPQRSTUVWXYZ" x 10_000_000;

$big_string .= "Easy as 123";
$big_string =~ /do-rey-mi/;
(substr $big_string, 100_000, 200) = "\xFF\xFF\xFF";

$big_string =~ /do-rey-mi/;
(substr $big_string, 200_000, 200) = "\xFF\xFF\xFF";

$big_string =~ /(\xFF\xFF\xFF)/;

if ($1) {

}
print "done!";
