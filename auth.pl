#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use LWP::Protocol::Net::Curl;
use Net::Twitter::Lite::WithAPIv1_1;
use Mojolicious::Lite;

my $consumer_key ="***";
my $consumer_secret = "***";

my $nt = Net::Twitter::Lite::WithAPIv1_1->new(
	consumer_key => $consumer_key,
	consumer_secret => $consumer_secret,
);

# Display top page
get '/' => sub {
	my $self = shift;
	$self->redirect_to( 'auth' );

} => 'index';

get '/auth' => sub {
	my $self = shift;
	my $cb_url = 'https://retrorocket.biz/upico/auth.cgi/auth_cb';
	my $url = $nt->get_authorization_url( callback => $cb_url );

	$self->session( token => $nt->request_token );
	$self->session( token_secret => $nt->request_token_secret );

	$self->redirect_to( $url );
} => 'auth';

get '/auth_cb' => sub {
	my $self = shift;
	my $verifier = $self->param('oauth_verifier') || '';
	my $token = $self->session('token') || '';
	my $token_secret = $self->session('token_secret') || '';

	$nt->request_token( $token );
	$nt->request_token_secret( $token_secret );

	# Access token取得
	my ($access_token, $access_token_secret, $user_id, $screen_name)
	= $nt->request_access_token( verifier => $verifier );

	# Sessionに格納
	$self->session( access_token => $access_token );
	$self->session( access_token_secret => $access_token_secret );
	$self->session( screen_name => $screen_name );

	$self->redirect_to( 'https://retrorocket.biz/upico/up.cgi' );
} => 'auth_cb';
# Session削除
get '/logout' => sub {
	my $self = shift;
	$self->session( expires => 1 );
	#$self->render;
} => 'logout';

##v1対応##
get '/v_one' => sub {
	my $self = shift;
	my $cb_url = 'https://retrorocket.biz/upico/auth.cgi/v_one_cb';
	my $url = $nt->get_authorization_url( callback => $cb_url );

	$self->session( token => $nt->request_token );
	$self->session( token_secret => $nt->request_token_secret );

	$self->redirect_to( $url );
} => 'v_one';

get '/v_one_cb' => sub {
	my $self = shift;
	my $verifier = $self->param('oauth_verifier') || '';
	my $token = $self->session('token') || '';
	my $token_secret = $self->session('token_secret') || '';

	$nt->request_token( $token );
	$nt->request_token_secret( $token_secret );

	# Access token取得
	my ($access_token, $access_token_secret, $user_id, $screen_name)
	= $nt->request_access_token( verifier => $verifier );

	# Sessionに格納
	$self->session( access_token => $access_token );
	$self->session( access_token_secret => $access_token_secret );
	$self->session( screen_name => $screen_name );

	$self->redirect_to( 'https://retrorocket.biz/upico/v_one.cgi' );
} => 'v_one_cb';

app->sessions->secure(1);
app->secret("***"); # セッション管理のために付けておく
app->start;

__DATA__

@@ error.html.ep
<!DOCTYPE html>
<html lang="ja">
	<head>
		<meta charset="utf-8">
		<title>Upload Twitter icon</title>
		<meta name="viewport" content="width=device-width, initial-scale=1.0">

		<!-- Le styles -->
		<link href="https://retrorocket.biz/upico/css/bootstrap.css" rel="stylesheet">
		<style>
			body {
				padding-top: 60px; /* 60px to make the container go all the way to the bottom of the topbar */
				padding-bottom: 40px;
			}
		</style>
		<link href="https://retrorocket.biz/upico/css/bootstrap-responsive.css" rel="stylesheet">

		<!-- HTML5 shim, for IE6-8 support of HTML5 elements -->
		<!--[if lt IE 9]>
		<script src="http://html5shim.googlecode.com/svn/trunk/html5.js"></script>
		<![endif]-->

		<!-- Fav and touch icons -->
	</head>

	<body>

		<div class="container">
			<h2>Error</h2>
			<p>
			<%= $exception %>
			</p>
			<p><a href="http://retrorocket.biz/upico/">戻る</a></p>
		</div> 
	</body>
</html>
