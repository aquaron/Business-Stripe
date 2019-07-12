use strict;
use warnings;
use Test::More tests => 26;

package MockUA;
    sub new        { bless $_[1], $_[0]     }
    sub request    { $_[0]->{request}->(@_) }
    sub is_success { $_[0]->{success}       }
    sub content    { $_[0]->{content}       }

package main;

use Business::Stripe;
pass 'Business::Stripe loaded successfully.';

ok my $stripe = Business::Stripe->new, 'Business::Stripe instantiation';

isa_ok $stripe, 'Business::Stripe';

is ref $stripe->{-ua}, 'LWP::UserAgent', 'got default user agent';
is $stripe->{-url}, 'https://api.stripe.com/v1/', 'default url is set';

ok !exists $stripe->{-api_key}, '-api_key not passed on object construction';
ok !exists $stripe->{-auth}, 'no -api_key means no -auth header';
is $stripe->api('get', 'whatever'), undef, 'no -auth means no request is made';

ok $stripe = Business::Stripe->new(
    -api_key => 123,
), 'Business::Stripe object with -api_key';

is $stripe->{-api_key}, 123, 'stored api key properly';
is $stripe->{-auth}, "Basic MTIz\n:", 'created auth from api_key';
is $stripe->{-url}, 'https://api.stripe.com/v1/', 'default url is still set';
ok $stripe = Business::Stripe->new(
    -api_key => 123,
    -url     => 'http://alternative.stripe.example.com/v8/',
), 'Business::Stripe object with -api_key and -url';
is $stripe->{-api_key}, 123, 'still stored api key properly';
is $stripe->{-url}, 'http://alternative.stripe.example.com/v8/', 'new url was set';

ok $stripe = Business::Stripe->new(
    -ua_args => { timeout => 7 }
), 'Business::Stripe with user agent arguments';

my $ua = $stripe->{-ua};
is $ua->timeout, 7, '-ua_args passed timeout properly';
undef $ua;

$stripe = Business::Stripe->new(
    -api_key => 123,
    -ua => MockUA->new({
        request => sub { return $_[0] },
        success => 1,
        content => '{"id":666}',
    }),
);

is $stripe->api('get', 'whatever'), 666, 'dummy request returned valid id';
my $res = $stripe->success;
is_deeply $res, { id => 666 }, 'returned success JSON parsed';

$stripe = Business::Stripe->new(
    -api_key => 123,
    -ua => MockUA->new({
        request => sub { return $_[0] },
        success => 1,
        content => '{"this":"has", "no":"id"}',
    }),
);

is $stripe->api('get', 'whatever'), 1, 'dummy request returned success without id';
$res = $stripe->success;
is_deeply $res, { this => 'has', no => 'id' }, 'returned success JSON parsed';

$stripe = Business::Stripe->new(
    -api_key => 123,
    -ua => MockUA->new({
        request => sub { return $_[0] },
        success => 0,
        content => '{"error":{"message": "this is a bogus error", "code": -7}}',
    }),
);

is $stripe->api('get', 'whatever'), 0, 'dummy request returned error';
$res = $stripe->error;
is_deeply(
    $res,
    {
        message => 'this is a bogus error',
        code    => -7
    },
    'returned error JSON parsed'
);

$stripe = Business::Stripe->new(
    -api_key        => 123,
    -version        => '2019-05-16',
    -stripe_account => 'other_user',
    -ua => MockUA->new({
        request => sub {
            my ($self, $req) = @_;
            Test::More::is($req->header('Authorization'), "Basic MTIz\n:", 'auth header');
            Test::More::is($req->header('Stripe-Version'), '2019-05-16', 'version header');
            Test::More::is($req->header('Stripe-Account'), 'other_user', 'account header');
            return $self;
        },
        success => 1,
        content => '{}',
    }),
);
$stripe->api('get', 'whatever');
