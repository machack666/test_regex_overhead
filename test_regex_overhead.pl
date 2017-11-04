#!/usr/bin/perl

use strict;
use warnings;
use autodie;

# latest versions in each major branch
my @default_versions = qw/5.8.9 5.10.1 5.12.5 5.14.4 5.16.3 5.18.4 5.20.3 5.22.3 5.24.1 5.26.1/;
my @target_versions = @ARGV ? @ARGV : @default_versions;

install_missing_versions();
setup_scripts();
run_tests();


#################### Routines ####################

sub run_tests {
    for my $vers (@target_versions) {
        print "Version: $vers (Encode, No Safe)\n";
        system("PLENV_VERSION=$vers time plenv exec perl with_encode_without_safe.pl");
        print "Version: $vers (Encode, Safe)\n";
        system("PLENV_VERSION=$vers time plenv exec perl with_encode_with_safe.pl");
        print "Version: $vers (No Encode, No Safe)\n";
        system("PLENV_VERSION=$vers time plenv exec perl without_encode_without_safe.pl");
        print "Version: $vers (No Encode, Safe)\n";
        system("PLENV_VERSION=$vers time plenv exec perl without_encode_with_safe.pl");
    }
}

sub setup_scripts {
    my @prog = <DATA>;

    open my $enc_safe, '>', 'with_encode_with_safe.pl';
    open my $enc_nosafe, '>', 'with_encode_without_safe.pl';
    open my $noenc_safe, '>', 'without_encode_with_safe.pl';
    open my $noenc_nosafe, '>', 'without_encode_without_safe.pl';

    for (@prog) {
        print $enc_safe $_;
        print $enc_nosafe $_ unless /Safe/;
        print $noenc_safe $_ unless /Encode/;
        print $noenc_nosafe $_ unless /Encode/ || /Safe/;
    }
    close $enc_safe;
    close $enc_nosafe;
    close $noenc_safe;
    close $noenc_nosafe;
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
use Safe;

my $highbit = "¿qué pasa?";     # Encode
$highbit =~ /¢/;                # Encode

Encode->find_encoding('utf8');

binmode(\*STDOUT, ':utf8');     # Encode

my $mySafe = new Safe();
$mySafe->untrap(qw/print/);

my $SafeStr = <<'EOSafe';
my $big_string = "ABCDEFGHIJKLMNOPQRSTUVWXYZ" x 10_000_000;
$big_string = "ABCDEFGHIJKLMNOPQRSTUVWXYZ" x 10_000_000;

$big_string .= "Easy as 123";
$big_string =~ /do-rey-mi/;

(substr $big_string, 100_000, 200) = "\xFF\xFF\xFF";

$big_string =~ /do-rey-mi/;
(substr $big_string, 200_000, 200) = "\xFF\xFF\xFF";

$big_string =~ /(\xFF\xFF\xFF)/;

if ($1) {

}

$big_string =~ s/XYZ//g; # don't like the XYZs!

$big_string =~ s/EFG/ABC/g;
$big_string =~ s/ABC/XXX/g;

print "done!";
EOSafe

$mySafe->reval($SafeStr);
warn "Safe had issues: $@" if $@;

