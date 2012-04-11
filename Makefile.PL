use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Business::Stripe',
    AUTHOR              => q{Paul Pham <pham@cpan.org>},
    VERSION_FROM        => 'Stripe.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Business-Stripe-*' },
    META_MERGE          => {
        resources       => {
            repository  => 'http://github.com/pham/Business-Stripe'
        }
    }
);
