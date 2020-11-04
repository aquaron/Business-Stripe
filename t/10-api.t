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

my $rand_auth = 'dummy' . int(rand(1000));

my @tests = (
    {
        api_args         => [ 'delete', 'plans/gold' ],
        http_method      => 'DELETE',
        http_uri         => 'https://api.stripe.com/v1/plans/gold',
        http_content     => '',
        http_headers     => {
            'Authorization' => $rand_auth,
            'Stripe-Version' => undef,
            'Stripe-Account' => undef,
        },
    },
    {
        api_args         => [ 'delete', 'plans', 'gold' ],
        http_method      => 'DELETE',
        http_uri         => 'https://api.stripe.com/v1/plans/gold',
        http_content     => '',
        http_headers     => {
            'Authorization' => $rand_auth,
            'Stripe-Version' => undef,
            'Stripe-Account' => undef,
        },
    },
    {
        api_args => [ 'post', 'customers',
            email       => 'myuser@example.com',
            name        => 'Jane Doe',
            description => 'Test description',
            source      => 1234,
        ],
        http_method      => 'POST',
        http_uri         => 'https://api.stripe.com/v1/customers',
        http_headers     => {
            'Authorization' => $rand_auth,
            'Stripe-Version' => undef,
            'Stripe-Account' => undef,
        },
        http_content => 'email=myuser%40example.com&name=Jane+Doe&description=Test+description&source=1234',
    },
    {
        api_args => [ 'get', 'subscriptions', '1234' ],
        http_method      => 'GET',
        http_uri         => 'https://api.stripe.com/v1/subscriptions/1234',
        http_content     => '',
        http_headers     => {
            'Authorization' => $rand_auth,
            'Stripe-Version' => undef,
            'Stripe-Account' => undef,
        },
    },
    {
        api_args => [ 'get', 'subscriptions',
            status   => 'cancelled',
            limit    => 3,
            plan     => 'superpro',
            whatever => undef,
        ],
        http_method      => 'GET',
        http_uri         => 'https://api.stripe.com/v1/subscriptions?limit=3&plan=superpro&status=cancelled&whatever=',
        http_content     => '',
        http_headers     => {
            'Authorization' => $rand_auth,
            'Stripe-Version' => undef,
            'Stripe-Account' => undef,
        },
    },
    {
        api_args => [ 'get', 'subscriptions',
            status           => 'cancelled',
            -idempotency_key => '111',
            -stripe_account  => '222',
            -authorization   => '333',
            -stripe_version  => '444',
        ],
        http_method      => 'GET',
        http_uri         => 'https://api.stripe.com/v1/subscriptions?status=cancelled',
        http_content     => '',
        http_headers     => {
            'Authorization'   => 333,
            'Stripe-Version'  => 444,
            'Stripe-Account'  => 222,
            'Idempotency-Key' => 111,
        },
    },
);

my $total_tests = 0;
foreach my $test (@tests) {
    $total_tests = $total_tests
        + 3 # http_method + http_uri + http_content
        + scalar(keys %{$test->{http_headers}})  # 1 test for each header key
        ;
}
plan tests => $total_tests + 5;

my $ua = MockUA->new({
    current_test => 0,
    tests        => \@tests,
    request      => sub {
        my ($self, $req) = @_;
        die 'no tests available' unless exists $self->{tests}[$self->{current_test}];

        my $current_test = $self->{tests}[$self->{current_test}];
        Test::More::is(
            $req->method,
            $current_test->{http_method},
            "HTTP::Request method #" . $self->{current_test}
        );
        Test::More::is(
            $req->uri,
            $current_test->{http_uri},
            "HTTP::Request uri #" . $self->{current_test}
        );
        foreach my $header_key (sort keys %{$current_test->{http_headers}}) {
            Test::More::is(
                $req->header($header_key),
                $current_test->{http_headers}{$header_key},
                "HTTP::Request has proper header value for '$header_key'",
            );
        }
        Test::More::is(
            $req->content,
            $current_test->{http_content},
            "HTTP::Request has proper content set for test $self->{current_test}"
        );

        $self->{current_test}++;
        return $self;
    },
    success => 1,
    content => '{}',
});

my $stripe = Business::Stripe->new(
    -auth => $rand_auth,
    -ua   => $ua,
);


foreach my $test_number (0 .. $#tests) {
    $stripe->api(@{$tests[$test_number]{api_args}});
}

{
    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings, @_; };

    $stripe = Business::Stripe->new(
        -auth => $rand_auth,
        -ua   => MockUA->new({
            request => sub { Test::More::fail('No request should be sent') },
        }),
    );
    $stripe->api('put', 'bogusroute');
    is scalar @warnings, 1, 'invalid http method triggers warning';
    like $warnings[0], qr{don't know how to handle put}, 'warning message received';

    undef @warnings;
    $stripe = Business::Stripe->new(
        -auth => $rand_auth,
        -ua   => MockUA->new({
            request => sub {
                my ($self, $req) = @_;
                Test::More::is($req->method, 'GET', 'proper method on invalid header key');
                return $self;
            },
            success => 1,
            content => '{}',
        }),
    );
    $stripe->api('get', 'subscribers', -invalid_key => 123);
    is scalar @warnings, 1, 'invalid http method triggers warning';
    like(
        $warnings[0],
        qr{don't know how to handle key '-invalid_key'. Ignored.},
        'warning message received'
    );
}
