#!/usr/bin/perl

use strict;
use warnings;
use utf8;
#use KCatch;
use LWP::Protocol::Net::Curl;
use Net::Twitter::Lite::WithAPIv1_1;
use Mojolicious::Lite;

my $consumer_key ="***";
my $consumer_secret = "***";

my $nt = Net::Twitter::Lite::WithAPIv1_1->new(
	consumer_key => $consumer_key,
	consumer_secret => $consumer_secret,
	ssl => 1
);

# トップページ
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

	# トークン取得
	my ($access_token, $access_token_secret, $user_id, $screen_name)
		= $nt->request_access_token( verifier => $verifier );

	# セッションに格納
	$self->session( access_token => $access_token );
	$self->session( access_token_secret => $access_token_secret );
	$self->session( screen_name => $screen_name );

	$self->redirect_to( 'https://retrorocket.biz/upico/up.cgi' );
} => 'auth_cb';

# セッション削除
get '/logout' => sub {
	my $self = shift;
	$self->session( expires => 1 );
} => 'logout';

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

		<link rel="stylesheet" href="https://retrorocket.biz/public/css/bootstrap.min.css" media="screen">
		<!--<link rel="stylesheet" href="https://retrorocket.biz/public/css/bootstrap-theme.min.css" media="screen">-->
		<!--[if lt IE 9]>
		<script src="https://oss.maxcdn.com/libs/html5shiv/3.7.0/html5shiv.js"></script>
		<script src="https://oss.maxcdn.com/libs/respond.js/1.3.0/respond.min.js"></script>
		<![endif]-->

		<!-- body padding調整-->
		<link rel="stylesheet" href="https://retrorocket.biz/public/css/unit.css" media="screen">

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

@@ exception.html.ep
<!DOCTYPE html>
<html lang="ja">
	<head>
		<meta charset="utf-8">
		<title>Upload Twitter icon</title>
		<meta name="viewport" content="width=device-width, initial-scale=1.0">

		<link rel="stylesheet" href="https://retrorocket.biz/public/css/bootstrap.min.css" media="screen">
		<!--<link rel="stylesheet" href="https://retrorocket.biz/public/css/bootstrap-theme.min.css" media="screen">-->
		<!--[if lt IE 9]>
		<script src="https://oss.maxcdn.com/libs/html5shiv/3.7.0/html5shiv.js"></script>
		<script src="https://oss.maxcdn.com/libs/respond.js/1.3.0/respond.min.js"></script>
		<![endif]-->

		<!-- body padding調整-->
		<link rel="stylesheet" href="https://retrorocket.biz/public/css/unit.css" media="screen">

	</head>

	<body>

		<div class="container">
			<h2>Exception</h2>
			<p>
			<%= $exception->message %>
			</p>
			<p><a href="http://retrorocket.biz/upico/">戻る</a></p>
		</div> 
	</body>
</html>

