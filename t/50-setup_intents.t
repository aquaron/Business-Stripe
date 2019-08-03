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

##############################
### setup_intents_create() ###
##############################
my $stripe = Business::Stripe->new(
    -api_key => 123,
    -ua => MockUA->new({
        success => 1,
        content => '{ "test": 1 }',
        request => sub {
            my ($self, $req) = @_;
            Test::More::is($req->method, 'POST', 'setup_intents_create method');
            Test::More::is(
                $req->uri,
                'https://api.stripe.com/v1/setup_intents',
                'setup_intents_create() uri'
            );
            my %params = map {split /=/} split /&/, $req->content;
            Test::More::is_deeply(
                \%params,
                {
                    amount => 100,
                    description => 'customer%40example.com',
                    currency    => 'usd',
                },
                'setup_intents_create() payload with default currency'
            );
            return $self;
        },
    }),
);

ok $stripe->setup_intents_create(
    amount      => 100,
    description => 'customer@example.com',
    currency    => 'usd',
), 'setup_intents_create()';
is_deeply $stripe->success, { test => 1 }, 'setup_intents_create inflates properly';


$stripe = Business::Stripe->new(
    -api_key => 123,
    -ua => MockUA->new({
        success => 1,
        content => '{ "test": 1 }',
        request => sub {
            my ($self, $req) = @_;
            Test::More::is($req->method, 'POST', 'setup_intents_create method (2nd round)');
            Test::More::is(
                $req->uri,
                'https://api.stripe.com/v1/setup_intents',
                'setup_intents_create() uri (2nd round)'
            );
            my %params = map {split /=/} split /&/, $req->content;
            Test::More::is_deeply(
                \%params,
                {
                    amount      => 2990,
                    description => 'other+user',
                    currency    => 'brl',
                },
                'setup_intents_create() payload with non-default currency'
            );
            return $self;
        },
    }),
);

ok $stripe->setup_intents_create(
    amount      => 2990,
    description => 'other user',
    currency    => 'brl',
), 'setup_intents_create() with non-default currency';
is_deeply $stripe->success, { test => 1 }, 'setup_intents_create inflates properly (2nd round)';


################################
### setup_intents_retrieve() ###
################################
$stripe = Business::Stripe->new(
    -api_key => 123,
    -ua => MockUA->new({
        success => 1,
        content => '{ "answer": 42 }',
        request => sub {
            my ($self, $req) = @_;
            Test::More::is($req->method, 'GET', 'setup_intents_retrieve() method');
            Test::More::is(
                $req->uri,
                'https://api.stripe.com/v1/setup_intents/my_setup_intents_id',
                'setup_intents_retrieve() uri'
            );
            is $req->content, '', 'setup_intents_retrieve() content';
            return $self;
        },
    }),
);

ok $stripe->setup_intents_retrieve('my_setup_intents_id'), 'setup_intents_retrieve() call';
is_deeply $stripe->success, { answer => 42 }, 'setup_intents_retrieve() inflates properly';


###############################
### setup_intents_confirm() ###
###############################
$stripe = Business::Stripe->new(
    -api_key => 123,
    -ua => MockUA->new({
        success => 1,
        content => '{ "payment_method": "pm_card_visa"}',
        request => sub {
            my ($self, $req) = @_;
            Test::More::is($req->method, 'POST', 'setup_intents_confirm() method');
            Test::More::is(
                $req->uri,
                'https://api.stripe.com/v1/setup_intents/my_setup_intents_id/confirm',
                'setup_intents_confirm() uri'
            );
            my %params = map {split /=/} split /&/, $req->content;
            Test::More::is_deeply(
                \%params,
                {
                    payment_method    => 'pm_card_visa',
                },
                'setup_intents_confirm() payload with pm_card_visa'
            );
            return $self;
        },
    }),
);

ok $stripe->setup_intents_confirm('my_setup_intents_id', 'payment_method' => 'pm_card_visa' ), 'setup_intents_confirm() call';
is_deeply $stripe->success, { payment_method => 'pm_card_visa' }, 'setup_intents_confirm() inflates properly';



##############################
### setup_intents_update() ###
##############################
$stripe = Business::Stripe->new(
    -api_key => 123,
    -ua => MockUA->new({
        success => 1,
        content => '{ "test": 1 }',
        request => sub {
            my ($self, $req) = @_;
            Test::More::is($req->method, 'POST', 'setup_intents_update() method');
            Test::More::is(
                $req->uri,
                'https://api.stripe.com/v1/setup_intents/my_setup_intent_id',
                'setup_intents_update() uri'
            );
            my %params = map {split /=/} split /&/, $req->content;
            Test::More::is_deeply(
                \%params,
                {
                    amount => 1,
                    description => 'customer%40example.com',
                    currency    => 'usd',
                },
                'setup_intents_update() payload with default currency'
            );
            return $self;
        },
    }),
);

ok $stripe->setup_intents_update('my_setup_intent_id', 
    amount      => 1,
    description => 'customer@example.com',
    currency    => 'usd'),  'setup_intents_update() full update call';
is_deeply $stripe->success, { "test" => 1 }, 'setup_intents_update() inflates properly';


################################
### setup_intents_cancel() #####
################################
$stripe = Business::Stripe->new(
    -api_key => 123,
    -ua => MockUA->new({
        success => 1,
        content => '{ "cancellation_reason": "duplicate" }',
        request => sub {
            my ($self, $req) = @_;
            Test::More::is($req->method, 'POST', 'setup_intents_cancel() method');
            Test::More::is(
                $req->uri,
                'https://api.stripe.com/v1/setup_intents/my_setup_intent_id/cancel',
                'setup_intents_cancel() uri'
            );
            my %params = map {split /=/} split /&/, $req->content;
            Test::More::is_deeply(
                \%params,
                {
                    cancellation_reason => "duplicate",
                },
                'setup_intents_update() payload'
            );

            return $self;
        },
    }),
);

ok $stripe->setup_intents_cancel('my_setup_intent_id', 'cancellation_reason', 'duplicate'),  'setup_intents_cancel() full update call';
is_deeply $stripe->success, { "cancellation_reason" => "duplicate" }, 'setup_intents_cancel() inflates properly';

$stripe = Business::Stripe->new(
    -api_key => 123,
    -ua => MockUA->new({
        success => 1,
        content => '{ "test": 1 }',
        request => sub {
            my ($self, $req) = @_;
            Test::More::is($req->method, 'POST', 'setup_intents_cancel() method');
            Test::More::is(
                $req->uri,
                'https://api.stripe.com/v1/setup_intents/my_setup_intent_id/cancel',
                'setup_intents_cancel() uri'
            );
            return $self;
        },
    }),
);

ok $stripe->setup_intents_cancel('my_setup_intent_id'),  'setup_intents_cancel() with no data';
is_deeply $stripe->success, { "test" => 1 }, 'setup_intents_cancel() inflates properly';


############################
### setup_intents_list() ###
############################
$stripe = Business::Stripe->new(
    -api_key => 123,
    -ua => MockUA->new({
        success => 1,
        content => '{}',
        request => sub {
            my ($self, $req) = @_;
            Test::More::is($req->method, 'GET', 'setup_intents_list() method with no params');
            Test::More::is(
                $req->uri,
                'https://api.stripe.com/v1/setup_intents',
                'setup_intents_list() uri'
            );
            is $req->content, '', 'setup_intents_list() content with no params';
            return $self;
        },
    }),
);

ok $stripe->setup_intents_list(), 'setup_intents_list() call';
is_deeply $stripe->success, {}, 'setup_intents_list() inflates properly';

$stripe = Business::Stripe->new(
    -api_key => 123,
    -ua => MockUA->new({
        success => 1,
        content => '{ "limit": 3, "customer": "someone" }',
        request => sub {
            my ($self, $req) = @_;
            Test::More::is($req->method, 'GET', 'setup_intents_list() method');
            Test::More::is(
                $req->uri,
                'https://api.stripe.com/v1/setup_intents?customer=someone&limit=3',
                'setup_intents_list() uri with params'
            );
            is $req->content, '', 'setup_intents_list() content';
            return $self;
        },
    }),
);

ok(
    $stripe->setup_intents_list( limit => 3, customer => 'someone' ),
    'setup_intents_list() call with params'
);
is_deeply $stripe->success, { limit => 3, customer => "someone" }, 'setup_intents_list() with params inflates properly';



done_testing;
