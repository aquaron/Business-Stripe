use strict;
use warnings;
use Test::More;

package MockUA;
    sub new        { bless $_[1], $_[0]     }
    sub request    { $_[0]->{request}->(@_) }
    sub is_success { $_[0]->{success}       }
    sub content    { $_[0]->{content}       }

package main;

use Business::Stripe;

########################
### charges_create() ###
########################
my $stripe = Business::Stripe->new(
    -api_key => 123,
    -ua => MockUA->new({
        success => 1,
        content => '{ "test": 1 }',
        request => sub {
            my ($self, $req) = @_;
            Test::More::is($req->method, 'POST', 'charges_create method');
            Test::More::is(
                $req->uri,
                'https://api.stripe.com/v1/charges',
                'charges_create() uri'
            );
            my %params = map {split /=/} split /&/, $req->content;
            Test::More::is_deeply(
                \%params,
                {
                    amount => 100,
                    description => 'customer%40example.com',
                    source      => 'tok_Wzm6ewTBrkVvC3',
                    currency    => 'usd',
                },
                'charges_create() payload with default currency'
            );
            return $self;
        },
    }),
);

ok $stripe->charges_create(
    amount      => 100,
    source      => 'tok_Wzm6ewTBrkVvC3',
    description => 'customer@example.com',
), 'charges_create()';
is_deeply $stripe->success, { test => 1 }, 'charges_create inflates properly';


$stripe = Business::Stripe->new(
    -api_key => 123,
    -ua => MockUA->new({
        success => 1,
        content => '{ "test": 1 }',
        request => sub {
            my ($self, $req) = @_;
            Test::More::is($req->method, 'POST', 'charges_create method (2nd round)');
            Test::More::is(
                $req->uri,
                'https://api.stripe.com/v1/charges',
                'charges_create() uri (2nd round)'
            );
            my %params = map {split /=/} split /&/, $req->content;
            Test::More::is_deeply(
                \%params,
                {
                    amount      => 2990,
                    description => 'other+user',
                    source      => 'tok_Wzm6ewTBrkVvC3',
                    currency    => 'brl',
                },
                'charges_create() payload with non-default currency'
            );
            return $self;
        },
    }),
);

ok $stripe->charges_create(
    amount      => 2990,
    source      => 'tok_Wzm6ewTBrkVvC3',
    description => 'other user',
    currency    => 'brl',
), 'charges_create() with non-default currency';
is_deeply $stripe->success, { test => 1 }, 'charges_create inflates properly (2nd round)';


##########################
### charges_retrieve() ###
##########################
$stripe = Business::Stripe->new(
    -api_key => 123,
    -ua => MockUA->new({
        success => 1,
        content => '{ "answer": 42 }',
        request => sub {
            my ($self, $req) = @_;
            Test::More::is($req->method, 'GET', 'charges_retrieve() method');
            Test::More::is(
                $req->uri,
                'https://api.stripe.com/v1/charges/23',
                'charges_retrieve() uri'
            );
            is $req->content, '', 'charges_retrieve() content';
            return $self;
        },
    }),
);

ok $stripe->charges_retrieve(23), 'charges_retrieve() call';
is_deeply $stripe->success, { answer => 42 }, 'charges_retrieve() inflates properly';

########################
### charges_refund() ###
########################
$stripe = Business::Stripe->new(
    -api_key => 123,
    -ua => MockUA->new({
        success => 1,
        content => '{}',
        request => sub {
            my ($self, $req) = @_;
            Test::More::is($req->method, 'POST', 'charges_refund() method');
            Test::More::is(
                $req->uri,
                'https://api.stripe.com/v1/charges/my_charge_id/refunds',
                'charges_refunds() uri'
            );
            is $req->content, '', 'charges_refunds() content';
            return $self;
        },
    }),
);

ok $stripe->charges_refund('my_charge_id'), 'charges_refund() full refund call';
is_deeply $stripe->success, {}, 'charges_refund() inflates properly';

$stripe = Business::Stripe->new(
    -api_key => 123,
    -ua => MockUA->new({
        success => 1,
        content => '{}',
        request => sub {
            my ($self, $req) = @_;
            Test::More::is($req->method, 'POST', 'charges_refund() method');
            Test::More::is(
                $req->uri,
                'https://api.stripe.com/v1/charges/my_charge_id/refunds',
                'charges_refund() uri'
            );
            is $req->content, 'amount=500', 'charges_refund() content has amount';
            return $self;
        },
    }),
);

ok $stripe->charges_refund('my_charge_id', 500), 'charges_refund() partial refund call';
is_deeply $stripe->success, {}, 'charges_refund() partial call inflates properly';


######################
### charges_list() ###
######################
$stripe = Business::Stripe->new(
    -api_key => 123,
    -ua => MockUA->new({
        success => 1,
        content => '{}',
        request => sub {
            my ($self, $req) = @_;
            Test::More::is($req->method, 'GET', 'charges_list() method');
            Test::More::is(
                $req->uri,
                'https://api.stripe.com/v1/charges',
                'charges_list() uri'
            );
            is $req->content, '', 'charges_list() content';
            return $self;
        },
    }),
);

ok $stripe->charges_list(), 'charges_list() call';
is_deeply $stripe->success, {}, 'charges_list() inflates properly';

$stripe = Business::Stripe->new(
    -api_key => 123,
    -ua => MockUA->new({
        success => 1,
        content => '{}',
        request => sub {
            my ($self, $req) = @_;
            Test::More::is($req->method, 'GET', 'charges_list() method');
            Test::More::is(
                $req->uri,
                'https://api.stripe.com/v1/charges?customer=someone&limit=5&whatever=',
                'charges_list() uri with params'
            );
            is $req->content, '', 'charges_list() content';
            return $self;
        },
    }),
);

ok(
    $stripe->charges_list( limit => 5, customer => 'someone', whatever => undef ),
    'charges_list() call with params'
);
is_deeply $stripe->success, {}, 'charges_list() with params inflates properly';



done_testing;
