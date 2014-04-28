#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use Net::Twitter::Lite::WithAPIv1_1;
use Mojolicious::Lite;
use File::Basename 'basename';
use File::Path 'mkpath';

my $consumer_key ="***";
my $consumer_secret = "***";

my $nt = Net::Twitter::Lite::WithAPIv1_1->new(
	consumer_key => $consumer_key,
	consumer_secret => $consumer_secret,
	ssl => 1
);
app->config(hypnotoad => {listen => ['http://*:sectret']});
app->hook('before_dispatch' => sub {
	my $self = shift;
	if ($self->req->headers->header('X-Forwarded-Host')) {
		my $path = shift @{$self->req->url->path->parts};
		push @{$self->req->url->base->path->parts}, $path;
	}
});
# Image base URL
my $IMAGE_BASE = app->home .'/xxx';
my $IMAGE_DIR  = $IMAGE_BASE;
# Create directory if not exists
unless (-d $IMAGE_DIR) {
	mkpath $IMAGE_DIR or die "Cannot create dirctory: $IMAGE_DIR";
}

get '/auth' => sub {
	my $self = shift;

	if($self->param('session')){
		$self->session( flag => $self->param('session') );
	}

	my $cb_url = $self->url_for('auth_cb')->to_abs->scheme('https');
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

	my ($access_token, $access_token_secret, $user_id, $screen_name)
	= $nt->request_access_token( verifier => $verifier );

	$self->session( access_token => $access_token );
	$self->session( access_token_secret => $access_token_secret );
	$self->session( screen_name => $screen_name );

	$self->redirect_to( $self->url_for('index')->to_abs->scheme('https') );
} => 'auth_cb';


get '/' => sub {
	my $self = shift;

	my $access_token = $self->session( 'access_token' ) || '';
	my $access_token_secret = $self->session( 'access_token_secret' ) || '';

	# セッションにトークンが残ってないならトップに飛ばす
	return $self->redirect_to( 'http://retrorocket.biz/upico' ) unless ($access_token && $access_token_secret);

} => 'index';

# Upload image file
post '/upload' => sub {
	my $self = shift;

	my $flag = 0;
	if($self->session( 'flag' )){ $flag = 1; }
	$self->stash('flag' => $flag);

	my $access_token = $self->session( 'access_token' ) || '';
	my $access_token_secret = $self->session( 'access_token_secret' ) || '';
	my $screen_name = $self->session( 'screen_name' ) || '';

	return $self->redirect_to( 'http://retrorocket.biz/upico' ) unless ($access_token && $access_token_secret);

	$nt->access_token( $access_token );
	$nt->access_token_secret( $access_token_secret );

	# Uploaded image(Mojo::Upload object)
	my $image = $self->req->upload('image');

	# Not upload
	unless ($image) {
		return $self->render(
			template => 'error',
			message  => "ファイルが選択されていません．"
		);
	}

	# Check file type
	my $image_type = $image->headers->content_type;
	my %valid_types = map {$_ => 1} qw(image/gif image/jpeg image/png);

	# Content type is wrong
	unless ($valid_types{$image_type}) {
		return $self->render(
			template => 'error',
			message  => "ファイルタイプが画像ではありません．"
		);
	}

	# Extention
	my $exts = {'image/gif' => 'gif', 'image/jpeg' => 'jpg',
		'image/png' => 'png'};
	my $ext = $exts->{$image_type};

	# Image file
	my $image_file = "$IMAGE_DIR/" . $screen_name . ".$ext";

	# If file is exists, Retry creating filename
	while(-f $image_file){
		my $rand_num = int(rand 100000);
		$image_file = "$IMAGE_DIR/" . $screen_name . $rand_num . ".$ext";
	}

	# Save to file
	$image->move_to($image_file);

	eval{
		$nt->update_profile_image([$image_file]);
		$self->stash('message' => "ファイルをアップロードしました");
	};
	if($@) { $self->stash('message' => "ファイルのアップロードに失敗しました（Twitter Error：".$@."）"); }
	$self->stash('name' => $screen_name);

	#ファイル削除
	unlink $image_file;
	if($flag == 0) {
	#セッション削除
		$self->session( expires => 1 );
	}

} => 'upload';


get '/logout' => sub {
	my $self = shift;
	$self->session( expires => 1 );
} => 'logout';

app->sessions->secure(1);
app->secrets(["xxx"]); # セッション管理のために付けておく
app->start;

