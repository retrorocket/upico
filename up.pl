#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use Net::Twitter::Lite::WithAPIv1_1;
use Mojolicious::Lite;
use File::Basename 'basename';
use File::Path 'mkpath';
#use KCatch;

my $consumer_key ="***";
my $consumer_secret = "***";

my $nt = Net::Twitter::Lite::WithAPIv1_1->new(
	consumer_key => $consumer_key,
	consumer_secret => $consumer_secret,
	ssl => 1
);

# Image base URL
my $IMAGE_BASE = app->home .'/public/image';
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

	# トークンが残っていない場合再認証
	my $url = 'https://retrorocket.biz/upico/auth.cgi';
	return $self->redirect_to( $url ) unless ($access_token && $access_token_secret);

} => 'index';

# Upload image file
post '/upload' => sub {
	my $self = shift;

	my $access_token = $self->session( 'access_token' ) || '';
	my $access_token_secret = $self->session( 'access_token_secret' ) || '';
	my $screen_name = $self->session( 'screen_name' ) || '';

	# トークンが残っていない場合再認証
	return $self->redirect_to( $url ) unless ($access_token && $access_token_secret);

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
	if($@) { $self->stash('message' => "ファイルのアップロードに失敗しました（".$@."）"); }
	$self->stash('name' => $screen_name);

	#ファイル削除
	unlink $image_file;

	#セッション削除
	$self->session( expires => 1 );

} => 'upload';

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
			<%= $message %>
			</p>
			<p><a href="http://retrorocket.biz/upico/">戻る</a></p>
		</div> 
	</body>
</html>

@@ index.html.ep
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

			<h2>アイコン画像を選択してください</h2>
			<p>アップロード出来る画像の容量は<span class = "text-danger">700KB</span>までです。</p>
			<p>
			<form action="<%= url_for('upload') %>" method="POST" ENCTYPE="multipart/form-data">
				<input type="file" name="image"><br>
				<hr>
				<button class="btn btn-primary" type="submit">OK</button><br />
			</form>
			</p>


		</div> <!-- /container -->
	</body>
</html>

@@ upload.html.ep
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
			<h2><%= $name %> 's icon image upload result</h2>
			<p>
			<%= $message %>
			</p>
			<p><a href="http://twitter.com/<%= $name %>">自分のついったーへ</a></p>
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
