#! /usr/bin/env perl
# Copyright 2015-2016 The OpenSSL Project Authors. All Rights Reserved.
#
# Licensed under the OpenSSL license (the "License").  You may not use
# this file except in compliance with the License.  You can obtain a copy
# in the file LICENSE in the source distribution or at
# https://www.openssl.org/source/license.html

use File::Spec;
use File::Copy;
use MIME::Base64;
use OpenSSL::Test qw(:DEFAULT srctop_file srctop_dir bldtop_file data_file);

my $test_name = "test_store";
setup($test_name);

# The MSYS2 run-time convert arguments that look like paths when executing
# a program unless that application is linked with the MSYS run-time.  The
# exact conversion rules are listed here:
#
#       http://www.mingw.org/wiki/Posix_path_conversion
#
# With the built-in configurations (all having names starting with "mingw"),
# the openssl application is not linked with the MSYS2 run-time, and therefore,
# it will receive possibly converted arguments from the process that executes
# it.  This conversion is fine for normal path arguments, but when those
# arguments are URIs, they sometimes aren't converted right (typically for
# URIs without an authority component, 'cause the conversion mechanism doesn't
# recognise them as URIs) or aren't converted at all (which gives perfectly
# normal absolute paths from the MSYS viewpoint, but don't work for the
# Windows run-time we're linked with).
#
# It's also possible to avoid conversion by defining MSYS2_ARG_CONV_EXCL with
# some suitable pattern ("*" to avoid conversions entirely), but that will
# again give us unconverted paths that don't work with the Windows run-time
# we're linked with.
#
# Checking for both msys perl operating environment and that the target name
# starts with "mingw", we're doing what we can to assure that other configs
# that might link openssl.exe with the MSYS run-time are not disturbed.
my $msys_mingw = ($^O eq 'msys') && (config('target') =~ m|^mingw|);

my @noexist_files =
    ( "test/blahdiblah.pem",
      "test/blahdibleh.der" );
my @src_files =
    ( "test/testx509.pem",
      "test/testrsa.pem",
      "test/testrsapub.pem",
      "test/testcrl.pem",
      "apps/server.pem" );
my @generated_files =
    (
     ### generated from the source files

     "testx509.der",
     "testrsa.der",
     "testrsapub.der",
     "testcrl.der",

     ### generated locally

     "rsa-key-pkcs1.pem", "rsa-key-pkcs1.der",
     "rsa-key-pkcs1-aes128.pem",
     "rsa-key-pkcs8.pem", "rsa-key-pkcs8.der",
     "rsa-key-pkcs8-pbes1-sha1-3des.pem", "rsa-key-pkcs8-pbes1-sha1-3des.der",
     "rsa-key-pkcs8-pbes2-sha1.pem", "rsa-key-pkcs8-pbes2-sha1.der",
     "rsa-key-sha1-3des-sha1.p12", "rsa-key-sha1-3des-sha256.p12",
     "rsa-key-aes256-cbc-sha256.p12",
     "rsa-key-md5-des-sha1.p12",
     "rsa-key-aes256-cbc-md5-des-sha256.p12",
     "rsa-key-pkcs8-pbes2-sha256.pem", "rsa-key-pkcs8-pbes2-sha256.der",
     "rsa-key-pkcs8-pbes1-md5-des.pem", "rsa-key-pkcs8-pbes1-md5-des.der",
     "dsa-key-pkcs1.pem", "dsa-key-pkcs1.der",
     "dsa-key-pkcs1-aes128.pem",
     "dsa-key-pkcs8.pem", "dsa-key-pkcs8.der",
     "dsa-key-pkcs8-pbes2-sha1.pem", "dsa-key-pkcs8-pbes2-sha1.der",
     "dsa-key-aes256-cbc-sha256.p12",
     "ec-key-pkcs1.pem", "ec-key-pkcs1.der",
     "ec-key-pkcs1-aes128.pem",
     "ec-key-pkcs8.pem", "ec-key-pkcs8.der",
     "ec-key-pkcs8-pbes2-sha1.pem", "ec-key-pkcs8-pbes2-sha1.der",
     "ec-key-aes256-cbc-sha256.p12",
    );
my %generated_file_files =
    $^O eq 'linux'
    ? ( "test/testx509.pem" => "file:testx509.pem",
        "test/testrsa.pem" => "file:testrsa.pem",
        "test/testrsapub.pem" => "file:testrsapub.pem",
        "test/testcrl.pem" => "file:testcrl.pem",
        "apps/server.pem" => "file:server.pem" )
    : ();
my @noexist_file_files =
    ( "file:blahdiblah.pem",
      "file:test/blahdibleh.der" );


my $n = (3 * scalar @noexist_files)
    + (6 * scalar @src_files)
    + (4 * scalar @generated_files)
    + (scalar keys %generated_file_files)
    + (scalar @noexist_file_files)
    + 4;

plan tests => $n;

indir "store_$$" => sub {
 SKIP:
    {
        skip "failed initialisation", $n unless init();

        # test PEM_read_bio_PrivateKey
        ok(run(app(["openssl", "rsa", "-in", "rsa-key-pkcs8-pbes2-sha256.pem",
                    "-passin", "pass:password"])));

        foreach (@noexist_files) {
            my $file = srctop_file($_);
        SKIP: {
                ok(!run(app(["openssl", "storeutl", $file])));
                ok(!run(app(["openssl", "storeutl", to_abs_file($file)])));

                skip "No test of URI form of $file for mingw", 1 if $msys_mingw;

                ok(!run(app(["openssl", "storeutl", to_abs_file_uri($file)])));
            }
        }
        foreach (@src_files) {
            my $file = srctop_file($_);
        SKIP: {
                ok(run(app(["openssl", "storeutl", $file])));
                ok(run(app(["openssl", "storeutl", to_abs_file($file)])));

                skip "No test of URI form of $file for mingw", 4 if $msys_mingw;

                ok(run(app(["openssl", "storeutl", to_abs_file_uri($file)])));
                ok(run(app(["openssl", "storeutl",
                            to_abs_file_uri($file, 0, "")])));
                ok(run(app(["openssl", "storeutl",
                            to_abs_file_uri($file, 0, "localhost")])));
                ok(!run(app(["openssl", "storeutl",
                             to_abs_file_uri($file, 0, "dummy")])));
            }
        }
        foreach (@generated_files) {
        SKIP: {
                ok(run(app(["openssl", "storeutl", "-passin", "pass:password",
                            $_])));
                ok(run(app(["openssl", "storeutl", "-passin", "pass:password",
                            to_abs_file($_)])));

                skip "No test of URI form of $_ for mingw", 2 if $msys_mingw;

                ok(run(app(["openssl", "storeutl", "-passin", "pass:password",
                            to_abs_file_uri($_)])));
                ok(!run(app(["openssl", "storeutl", "-passin", "pass:password",
                             to_file_uri($_)])));
            }
        }
        foreach (values %generated_file_files) {
        SKIP: {
                skip "No test of $_ for mingw", 1 if $msys_mingw;

                ok(run(app(["openssl", "storeutl", $_])));
            }
        }
        foreach (@noexist_file_files) {
        SKIP: {
                skip "No test of $_ for mingw", 1 if $msys_mingw;

                ok(!run(app(["openssl", "storeutl", $_])));
            }
        }
        {
            my $dir = srctop_dir("test", "certs");
        SKIP: {
                ok(run(app(["openssl", "storeutl", $dir])));
                ok(run(app(["openssl", "storeutl", to_abs_file($dir, 1)])));

                skip "No test of URI form of $dir for mingw", 1 if $msys_mingw;

                ok(run(app(["openssl", "storeutl", to_abs_file_uri($dir, 1)])));
            }
        }
    }
}, create => 1, cleanup => 1;

sub init {
    return (
            # rsa-key-pkcs1.pem
            run(app(["openssl", "genrsa",
                     "-out", "rsa-key-pkcs1.pem", "2432"]))
            # dsa-key-pkcs1.pem
            && run(app(["openssl", "dsaparam", "-genkey",
                        "-out", "dsa-key-pkcs1.pem", "1024"]))
            # ec-key-pkcs1.pem (one might think that 'genec' would be practical)
            && run(app(["openssl", "ecparam", "-genkey", "-name", "prime256v1",
                        "-out", "ec-key-pkcs1.pem"]))
            # rsa-key-pkcs1-aes128.pem
            && run(app(["openssl", "rsa", "-passout", "pass:password", "-aes128",
                        "-in", "rsa-key-pkcs1.pem",
                        "-out", "rsa-key-pkcs1-aes128.pem"]))
            # dsa-key-pkcs1-aes128.pem
            && run(app(["openssl", "dsa", "-passout", "pass:password", "-aes128",
                        "-in", "dsa-key-pkcs1.pem",
                        "-out", "dsa-key-pkcs1-aes128.pem"]))
            # ec-key-pkcs1-aes128.pem
            && run(app(["openssl", "ec", "-passout", "pass:password", "-aes128",
                        "-in", "ec-key-pkcs1.pem",
                        "-out", "ec-key-pkcs1-aes128.pem"]))
            # *-key-pkcs8.pem
            && runall(sub {
                          my $dstfile = shift;
                          (my $srcfile = $dstfile)
                              =~ s/-key-pkcs8\.pem$/-key-pkcs1.pem/i;
                          run(app(["openssl", "pkcs8", "-topk8", "-nocrypt",
                                   "-in", $srcfile, "-out", $dstfile]));
                      }, grep(/-key-pkcs8\.pem$/, @generated_files))
            # *-key-pkcs8-pbes1-sha1-3des.pem
            && runall(sub {
                          my $dstfile = shift;
                          (my $srcfile = $dstfile)
                              =~ s/-key-pkcs8-pbes1-sha1-3des\.pem$
                                  /-key-pkcs8.pem/ix;
                          run(app(["openssl", "pkcs8", "-topk8",
                                   "-passout", "pass:password",
                                   "-v1", "pbeWithSHA1And3-KeyTripleDES-CBC",
                                   "-in", $srcfile, "-out", $dstfile]));
                      }, grep(/-key-pkcs8-pbes1-sha1-3des\.pem$/, @generated_files))
            # *-key-pkcs8-pbes1-md5-des.pem
            && runall(sub {
                          my $dstfile = shift;
                          (my $srcfile = $dstfile)
                              =~ s/-key-pkcs8-pbes1-md5-des\.pem$
                                  /-key-pkcs8.pem/ix;
                          run(app(["openssl", "pkcs8", "-topk8",
                                   "-passout", "pass:password",
                                   "-v1", "pbeWithSHA1And3-KeyTripleDES-CBC",
                                   "-in", $srcfile, "-out", $dstfile]));
                      }, grep(/-key-pkcs8-pbes1-md5-des\.pem$/, @generated_files))
            # *-key-pkcs8-pbes2-sha1.pem
            && runall(sub {
                          my $dstfile = shift;
                          (my $srcfile = $dstfile)
                              =~ s/-key-pkcs8-pbes2-sha1\.pem$
                                  /-key-pkcs8.pem/ix;
                          run(app(["openssl", "pkcs8", "-topk8",
                                   "-passout", "pass:password",
                                   "-v2", "aes256", "-v2prf", "hmacWithSHA1",
                                   "-in", $srcfile, "-out", $dstfile]));
                      }, grep(/-key-pkcs8-pbes2-sha1\.pem$/, @generated_files))
            # *-key-pkcs8-pbes2-sha1.pem
            && runall(sub {
                          my $dstfile = shift;
                          (my $srcfile = $dstfile)
                              =~ s/-key-pkcs8-pbes2-sha256\.pem$
                                  /-key-pkcs8.pem/ix;
                          run(app(["openssl", "pkcs8", "-topk8",
                                   "-passout", "pass:password",
                                   "-v2", "aes256", "-v2prf", "hmacWithSHA256",
                                   "-in", $srcfile, "-out", $dstfile]));
                      }, grep(/-key-pkcs8-pbes2-sha256\.pem$/, @generated_files))
            # *-cert.pem (intermediary for the .p12 inits)
            && run(app(["openssl", "req", "-x509",
                        "-config", data_file("ca.cnf"), "-nodes",
                        "-out", "cacert.pem", "-keyout", "cakey.pem"]))
            && runall(sub {
                          my $srckey = shift;
                          (my $dstfile = $srckey) =~ s|-key-pkcs8\.|-cert.|;
                          (my $csr = $dstfile) =~ s|\.pem|.csr|;

                          (run(app(["openssl", "req", "-new",
                                    "-config", data_file("user.cnf"),
                                    "-key", $srckey, "-out", $csr]))
                           &&
                           run(app(["openssl", "x509", "-days", "3650",
                                    "-CA", "cacert.pem",
                                    "-CAkey", "cakey.pem",
                                    "-set_serial", time(), "-req",
                                    "-in", $csr, "-out", $dstfile])));
                      }, grep(/-key-pkcs8\.pem$/, @generated_files))
            # *.p12
            && runall(sub {
                          my $dstfile = shift;
                          my ($type, $certpbe_index, $keypbe_index,
                              $macalg_index) =
                              $dstfile =~ m{^(.*)-key-(?|
                                                # cert and key PBE are same
                                                ()             #
                                                ([^-]*-[^-]*)- # key & cert PBE
                                                ([^-]*)        # MACalg
                                            |
                                                # cert and key PBE are not same
                                                ([^-]*-[^-]*)- # cert PBE
                                                ([^-]*-[^-]*)- # key PBE
                                                ([^-]*)        # MACalg
                                            )\.}x;
                          if (!$certpbe_index) {
                              $certpbe_index = $keypbe_index;
                          }
                          my $srckey = "$type-key-pkcs8.pem";
                          my $srccert = "$type-cert.pem";
                          my %pbes =
                              (
                               "sha1-3des" => "pbeWithSHA1And3-KeyTripleDES-CBC",
                               "md5-des" => "pbeWithMD5AndDES-CBC",
                               "aes256-cbc" => "AES-256-CBC",
                              );
                          my %macalgs =
                              (
                               "sha1" => "SHA1",
                               "sha256" => "SHA256",
                              );
                          my $certpbe = $pbes{$certpbe_index};
                          my $keypbe = $pbes{$keypbe_index};
                          my $macalg = $macalgs{$macalg_index};
                          if (!defined($certpbe) || !defined($keypbe)
                              || !defined($macalg)) {
                              print STDERR "Cert PBE for $pbe_index not defined\n"
                                  unless defined $certpbe;
                              print STDERR "Key PBE for $pbe_index not defined\n"
                                  unless defined $keypbe;
                              print STDERR "MACALG for $macalg_index not defined\n"
                                  unless defined $macalg;
                              print STDERR "(destination file was $dstfile)\n";
                              return 0;
                          }
                          run(app(["openssl", "pkcs12", "-inkey", $srckey,
                                   "-in", $srccert, "-passout", "pass:password",
                                   "-export", "-macalg", $macalg,
                                   "-certpbe", $certpbe, "-keypbe", $keypbe,
                                   "-out", $dstfile]));
                      }, grep(/\.p12/, @generated_files))
            # *.der (the end all init)
            && runall(sub {
                          my $dstfile = shift;
                          (my $srcfile = $dstfile) =~ s/\.der$/.pem/i;
                          if (! -f $srcfile) {
                              $srcfile = srctop_file("test", $srcfile);
                          }
                          my $infh;
                          unless (open $infh, $srcfile) {
                              return 0;
                          }
                          my $l;
                          while (($l = <$infh>) !~ /^-----BEGIN\s/
                                 || $l =~ /^-----BEGIN.*PARAMETERS-----/) {
                          }
                          my $b64 = "";
                          while (($l = <$infh>) !~ /^-----END\s/) {
                              $l =~ s|\R$||;
                              $b64 .= $l unless $l =~ /:/;
                          }
                          close $infh;
                          my $der = decode_base64($b64);
                          unless (length($b64) / 4 * 3 - length($der) < 3) {
                              print STDERR "Length error, ",length($b64),
                                  " bytes of base64 became ",length($der),
                                  " bytes of der? ($srcfile => $dstfile)\n";
                              return 0;
                          }
                          my $outfh;
                          unless (open $outfh, ">:raw", $dstfile) {
                              return 0;
                          }
                          print $outfh $der;
                          close $outfh;
                          return 1;
                      }, grep(/\.der$/, @generated_files))
            && runall(sub {
                          my $srcfile = shift;
                          my $dstfile = $generated_file_files{$srcfile};

                          unless (copy srctop_file($srcfile), $dstfile) {
                              warn "$!\n";
                              return 0;
                          }
                          return 1;
                      }, keys %generated_file_files)
           );
}

sub runall {
    my ($function, @items) = @_;

    foreach (@items) {
        return 0 unless $function->($_);
    }
    return 1;
}

# According to RFC8089, a relative file: path is invalid.  We still produce
# them for testing purposes.
sub to_file_uri {
    my ($file, $isdir, $authority) = @_;
    my $vol;
    my $dir;

    die "to_file_uri: No file given\n" if !defined($file) || $file eq '';

    ($vol, $dir, $file) = File::Spec->splitpath($file, $isdir // 0);

    # Make sure we have a Unix style directory.
    $dir = join('/', File::Spec->splitdir($dir));
    # Canonicalise it (note: it seems to be only needed on Unix)
    while (1) {
        my $newdir = $dir;
        $newdir =~ s|/[^/]*[^/\.]+[^/]*/\.\./|/|g;
        last if $newdir eq $dir;
        $dir = $newdir;
    }
    # Take care of the corner cases the loop can't handle, and that $dir
    # ends with a / unless it's empty
    $dir =~ s|/[^/]*[^/\.]+[^/]*/\.\.$|/|;
    $dir =~ s|^[^/]*[^/\.]+[^/]*/\.\./|/|;
    $dir =~ s|^[^/]*[^/\.]+[^/]*/\.\.$||;
    if ($isdir // 0) {
        $dir =~ s|/$|| if $dir ne '/';
    } else {
        $dir .= '/' if $dir ne '' && $dir !~ m|/$|;
    }

    # If the file system has separate volumes (at present, Windows and VMS)
    # we need to handle them.  In URIs, they are invariably the first
    # component of the path, which is always absolute.
    # On VMS, user:[foo.bar] translates to /user/foo/bar
    # On Windows, c:\Users\Foo translates to /c:/Users/Foo
    if ($vol ne '') {
        $vol =~ s|:||g if ($^O eq "VMS");
        $dir = '/' . $dir if $dir ne '' && $dir !~ m|^/|;
        $dir = '/' . $vol . $dir;
    }
    $file = $dir . $file;

    return "file://$authority$file" if defined $authority;
    return "file:$file";
}

sub to_abs_file {
    my ($file) = @_;

    return File::Spec->rel2abs($file);
}

sub to_abs_file_uri {
    my ($file, $isdir, $authority) = @_;

    die "to_abs_file_uri: No file given\n" if !defined($file) || $file eq '';
    return to_file_uri(to_abs_file($file), $isdir, $authority);
}
