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
### customers_create() ###
########################
my $stripe = Business::Stripe->new(
    -api_key => 123,
    -ua => MockUA->new({
        success => 1,
        content => '{ "test": 1 }',
        request => sub {
            my ($self, $req) = @_;
            Test::More::is($req->method, 'POST', 'customers_create method');
            Test::More::is(
                $req->uri,
                'https://api.stripe.com/v1/customers',
                'customers_create() uri'
            );
            my %params = map {split /=/} split /&/, $req->content;
            Test::More::is_deeply(
                \%params,
                {
                    source      => 'tok_Wzm6ewTBrkVvC3',
                    email       => 'customer%40example.com',
                    description => 'userid-123456'
                },
                'customers_create() payload with default currency'
            );
            return $self;
        },
    }),
);

ok $stripe->customers_create(
    source      => 'tok_Wzm6ewTBrkVvC3',
    email       => 'customer@example.com',
    description => 'userid-123456'
), 'customers_create()';
is_deeply $stripe->success, { test => 1 }, 'customers_create inflates properly';


##########################
### customers_retrieve() ###
##########################
$stripe = Business::Stripe->new(
    -api_key => 123,
    -ua => MockUA->new({
        success => 1,
        content => '{ "answer": 42 }',
        request => sub {
            my ($self, $req) = @_;
            Test::More::is($req->method, 'GET', 'customers_retrieve() method');
            Test::More::is(
                $req->uri,
                'https://api.stripe.com/v1/customers/23',
                'customers_retrieve() uri'
            );
            is $req->content, '', 'customers_retrieve() content';
            return $self;
        },
    }),
);

ok $stripe->customers_retrieve(23), 'customers_retrieve() call';
is_deeply $stripe->success, { answer => 42 }, 'customers_retrieve() inflates properly';


########################
### customers_update() ###
########################
$stripe = Business::Stripe->new(
    -api_key => 123,
    -ua => MockUA->new({
        success => 1,
        content => '{}',
        request => sub {
            my ($self, $req) = @_;
            Test::More::is($req->method, 'POST', 'customers_update() method');
            Test::More::is(
                $req->uri,
                'https://api.stripe.com/v1/customers/my_customer_id',
                'customers_refunds() uri'
            );
            is $req->content, 'email=foo', 'customers_refunds() content';
            return $self;
        },
    }),
);

ok $stripe->customers_update('my_customer_id', email => 'foo'), 'customers_update() call';
is_deeply $stripe->success, {}, 'customers_update() inflates properly';

##########################
### customers_delete() ###
##########################
$stripe = Business::Stripe->new(
    -api_key => 123,
    -ua => MockUA->new({
        success => 1,
        content => '{}',
        request => sub {
            my ($self, $req) = @_;
            Test::More::is($req->method, 'DELETE', 'customers_delete() method');
            Test::More::is(
                $req->uri,
                'https://api.stripe.com/v1/customers/some_customer_id',
                'customers_delete() uri'
            );
            is $req->content, '', 'customers_delete() content';
            return $self;
        },
    }),
);

ok $stripe->customers_delete('some_customer_id'), 'customers_delete() call';
is_deeply $stripe->success, {}, 'customers_delete() inflates properly';


######################
### customers_list() ###
######################
$stripe = Business::Stripe->new(
    -api_key => 123,
    -ua => MockUA->new({
        success => 1,
        content => '{}',
        request => sub {
            my ($self, $req) = @_;
            Test::More::is($req->method, 'GET', 'customers_list() method');
            Test::More::is(
                $req->uri,
                'https://api.stripe.com/v1/customers',
                'customers_list() uri'
            );
            is $req->content, '', 'customers_list() content';
            return $self;
        },
    }),
);

ok $stripe->customers_list(), 'customers_list() call';
is_deeply $stripe->success, {}, 'customers_list() inflates properly';

$stripe = Business::Stripe->new(
    -api_key => 123,
    -ua => MockUA->new({
        success => 1,
        content => '{}',
        request => sub {
            my ($self, $req) = @_;
            Test::More::is($req->method, 'GET', 'customers_list() method');
            Test::More::is(
                $req->uri,
                'https://api.stripe.com/v1/customers?email=someone&limit=5&whatever=',
                'customers_list() uri with params'
            );
            is $req->content, '', 'customers_list() content';
            return $self;
        },
    }),
);

ok(
    $stripe->customers_list( limit => 5, email => 'someone', whatever => undef ),
    'customers_list() call with params'
);
is_deeply $stripe->success, {}, 'customers_list() with params inflates properly';

#############################
### customers_subscribe() ###
#############################
$stripe = Business::Stripe->new(
    -api_key => 123,
    -ua => MockUA->new({
        success => 1,
        content => '{}',
        request => sub {
            my ($self, $req) = @_;
            Test::More::is($req->method, 'POST', 'customers_subscribe() method');
            Test::More::is(
                $req->uri,
                'https://api.stripe.com/v1/customers/janedoe/subscriptions',
                'customers_subscribe() uri'
            );
            is $req->content, 'items%5B0%5D%5Bplan%5D=3', 'customers_subscribe() content';
            return $self;
        },
    }),
);

ok(
    $stripe->customers_subscribe('janedoe', 'items[0][plan]' => 3),
    'customers_subscribe() call'
);
is_deeply $stripe->success, {}, 'customers_subscribe() inflates properly';

###############################
### customers_unsubscribe() ###
###############################
$stripe = Business::Stripe->new(
    -api_key => 123,
    -ua => MockUA->new({
        success => 1,
        content => '{}',
        request => sub {
            my ($self, $req) = @_;
            Test::More::is($req->method, 'DELETE', 'customers_unsubscribe() method');
            Test::More::is(
                $req->uri,
                'https://api.stripe.com/v1/customers/janedoe/subscriptions',
                'customers_unsubscribe() uri'
            );
            is $req->content, '', 'customers_unsubscribe() content';
            return $self;
        },
    }),
);

ok(
    $stripe->customers_unsubscribe('janedoe'),
    'customers_subscribe() call'
);
is_deeply $stripe->success, {}, 'customers_subscribe() inflates properly';


done_testing;
