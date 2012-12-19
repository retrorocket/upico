#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use Mojolicious::Lite;
use Net::Twitter::Lite;
use File::Basename 'basename';
use File::Path 'mkpath';

my $consumer_key ="***";
my $consumer_secret = "***";

my $nt = Net::Twitter::Lite->new(
	consumer_key => $consumer_key,
	consumer_secret => $consumer_secret,
	legacy_lists_api => 1
);

# Image base URL
my $IMAGE_BASE = app->static->root .'/image';

my $IMAGE_DIR  = $IMAGE_BASE;

# Create directory if not exists
unless (-d $IMAGE_DIR) {
	mkpath $IMAGE_DIR or die "Cannot create dirctory: $IMAGE_DIR";
}

# Display top page
get '/' => sub {

	my $self = shift;

	my $access_token = $self->session( 'access_token' ) || '';
	my $access_token_secret = $self->session( 'access_token_secret' ) || '';
	my $screen_name = $self->session( 'screen_name' ) || '';

	# セッションにaccess_tokenが残ってなければ再認証
	return $self->redirect_to( 'auth' ) unless ($access_token && $access_token_secret);

} => 'index';

# Upload image file
post '/upload' => sub {
	my $self = shift;

	my $access_token = $self->session( 'access_token' ) || '';
	my $access_token_secret = $self->session( 'access_token_secret' ) || '';
	my $screen_name = $self->session( 'screen_name' ) || '';

	# セッションにaccess_tokenが残ってなければindexに強制送還
	return $self->redirect_to( 'index' ) unless ($access_token && $access_token_secret);

	$nt->access_token( $access_token );
	$nt->access_token_secret( $access_token_secret );

	#アイコン画像
	my $image = $self->req->upload('image');

	#ファイルが空
	unless ($image) {
		return $self->render(
			template => 'error',
			message  => "ファイルが選択されていません．"
		);
	}

	#ファイルタイプチェック
	my $image_type = $image->headers->content_type;
	my %valid_types = map {$_ => 1} qw(image/gif image/jpeg image/png);

	#ファイルタイプエラー
	unless ($valid_types{$image_type}) {
		return $self->render(
			template => 'error',
			message  => "ファイルタイプが画像ではありません．"
		);
	}

	#拡張子判定
	my $exts = {'image/gif' => 'gif', 'image/jpeg' => 'jpg',
		'image/png' => 'png'};
	my $ext = $exts->{$image_type};

	#アイコン画像までのパス
	my $image_file = "$IMAGE_DIR/" . create_filename(). ".$ext";

	#既に存在してた場合
	while(-f $image_file){
		$image_file = "$IMAGE_DIR/" . create_filename() . ".$ext";
	}

	#画像を一時保管
	$image->move_to($image_file);

	eval{
		$nt->update_profile_image([$image_file]);
		$self->session( expires => 1 );
		$self->stash('message' => "ファイルをアップロードしました");
		#$self->render();
	};
	if($@) { $self->stash('message' => "ファイルのアップロードに失敗しました"); }
	$self->stash('name' => $screen_name);

	#画像ファイル削除
	unlink $image_file;

	#セッション削除
	$self->session( expires => 1 );

} => 'upload';

get '/auth' => sub {
	my $self = shift;
	my $cb_url = '***';
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

	$self->redirect_to( 'index' );
} => 'auth_cb';

sub create_filename {

	# Date and time
	my ($sec, $min, $hour, $mday, $month, $year) = localtime;
	$month = $month + 1;
	$year = $year + 1900;

	# Random number(0 ~ 99999)
	my $rand_num = int(rand 100000);

	# Create file name form datatime and random number
	# (like image-20091014051023-78973)
	my $name = sprintf("image-%04s%02s%02s%02s%02s%02s-%05s",
		$year, $month, $mday, $hour, $min, $sec, $rand_num);

	return $name;
}

# セッション管理のために付けておく
app->secret("***");

app->start;

