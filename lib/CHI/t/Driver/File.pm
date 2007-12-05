package CHI::t::Driver::File;
use strict;
use warnings;
use CHI::Test;
use File::Basename;
use File::Temp qw(tempdir);
use base qw(CHI::t::Driver);

my $root_dir;

sub new_cache_options {
    my $self = shift;

    $root_dir ||= tempdir( "chi-driver-file-XXXX", TMPDIR => 1, CLEANUP => 1 );
    return ( $self->SUPER::new_cache_options(), root_dir => $root_dir );
}

sub set_standard_keys_and_values {
    my ($self) = @_;

    my ( $keys, $values ) = $self->SUPER::set_standard_keys_and_values();

    # keys have max length of 255 or so
    $keys->{'large'} = scalar( 'ab' x 125 );

    return ( $keys, $values );
}

sub test_path_to_key : Test(3) {
    my ($self) = @_;

    my $key;
    my $cache = $self->new_cache;
    my $log = CHI::Test::Logger->new();
    CHI->logger($log);

    $key = "\$20.00 plus 5% = \$25.00";
    my $file = basename(($cache->path_to_key($key))[0]);
    is($file, "+2420+2e00+20plus+205+25+20=+20+2425+2e00.dat", "path_to_key for key with mixed chars");

    # Should escape to over 255 chars
    $log->clear();
    $key = "!@#" x 100;
    cmp_deeply([$cache->path_to_key($key)], [], "path_to_key returned empty list for too-long key");
    $log->contains_ok(qr/key .* > \d+ chars when escaped; cannot cache/);
}

sub test_creation_and_deletion : Test(10) {
    my $self = shift;

    my $cache = $self->new_cache();
    is( $cache->depth, 2 );

    my ( $key, $value ) = $self->kvpair();
    my ($cache_file) = $cache->path_to_key($key);
    my $namespace_dir = $cache->path_to_namespace();
    ok( !-f $cache_file, "cache file '$cache_file' does not exist before set" );

    $cache->set( $key, $value, 0 );
    ok( !defined $cache->get($key) );
    ok( -f $cache_file,    "cache file '$cache_file' exists after set" );
    ok( -d $namespace_dir, "namespace dir '$namespace_dir' exists after set" );
    is( ( stat $cache_file )[2] & 07777, 0664, "'$cache_file' has mode 0664" );
    is( ( stat $namespace_dir )[2] & 07777,
        0775, "'$namespace_dir' has mode 0775" );

    $cache->remove($key);
    ok( !-f $cache_file,
        "cache file '$cache_file' does not exist after remove" );
    ok( -d $namespace_dir,
        "namespace dir '$namespace_dir' exists after remove" );

    $cache->clear();
    ok( !-d $namespace_dir,
        "namespace dir '$namespace_dir' does not exist after clear" );
}

1;
