S3MultiUpload
========

A jQuery plugin for direct upload to an Amazon S3 bucket. Modified from http://github.com/slaskis/s3upload to allow multiple
files to be simultaneously uploaded.

It works by replacing any element with a div overlaid with a transparent SWF. The same way [Flickr](http://www.flickr.com/photos/upload/) does it.

By signing the request server side we also avoid the security issue of showing the Amazon AWS Access Id Key and Secure Key in plain text. A library for signing the request in Ruby is available in the S3Upload project : http://github.com/slaskis/s3upload

The Javascript API also allows these callback functions:

* onselect(infoarray) 	- Called when a user has selected one or more files.
* oncancel(info) 	- Called if the user decides to abort the file browsing.
* onstart(info) 	- Called after the request has been signed and the file upload to S3 is starting.
* onprogress(progress,info) - Called while uploading, "progress" being a float between 0 and 1 of the current upload progress.
* oncomplete(info) 	- Called when the upload has finished successfully.
* onerror(msg,info) - Called if there's been a problem with a message saying what failed.
* onenabled()		- Called when the SWF has been enabled. Usually when swf.enable() has been called. Called first thing when the SWF is finished initializing.
* ondisabled()		- Called when the SWF has been disabled. Usually when swf.disable() has been called.

_info_ is an object containing "name", "size" and "type" of the selected file.
_infoarray_ is an array of _info_ objects.

And these mouse callbacks:

* onmouseover(x,y)
* onmouseout(x,y)
* onmousedown(x,y)
* onmouseup(x,y)
* onmousemove(x,y)
* onclick(x,y)
* onrollover(x,y)
* onrollout(x,y)
* ondoubleclick(x,y)

The mouse events are also triggered as regular jQuery events (i.e. `$('#input_replaced').rollover(function(){alert('over!')});` should work just fine as well).

Every callback is scoped to the DOM element which has replaced the previous input (i.e. "this" in the callbacks points to the html element). Also by returning `true` in a callback function the default callback will be used.

Which file types that can be selected may be defined with the _file\_types_ option, see the "Usage Example" below for more info. If none is defined all files are acceptable.


Requirements
-------------

* jQuery 1.3+
* SWFObject 2.1+

Both available from Google AJAX APIs (recommended as it likely speeds things up).


Example Usage
-------------

The HTML/JS part:

	<script type="text/javascript" charset="utf-8" src="http://ajax.googleapis.com/ajax/libs/jquery/1.4/jquery.min.js"></script>
	<script type="text/javascript" charset="utf-8" src="http://ajax.googleapis.com/ajax/libs/swfobject/2.2/swfobject.js"></script>
	<script type="text/javascript" charset="utf-8" src="jquery.s3multiupload.js"></script>

	<script type="text/javascript" charset="utf-8">
		$(function(){
			var max_file_size = 2 * 1024 * 1024; // = 2Mb
			$("form").s3_multiupload({
				prefix: "s3upload/",
				required: true,
				onselect: function(info) {
					if( parseInt( info.size ) < max_file_size )
						return true; // Default is to show the filename in the element.
					else
						$(this).html("Too big file! Must be smaller than " + max_file_size + " (was "+info.size+")");
				},
				file_types: [
					[ "Images" , "*.png;*.jpg;*.bmp"],
					[ "Documents" , "*.pdf;*.doc;*.txt"]
				]
			});
		});
	</script>

	<form action="/media/new" method="post" accept-charset="utf-8" enctype="multipart/form-data">
		<label for="media_title">Title</label>
		<input type="text" name="media[title]" value="" id="media_title" />
		<label for="media_video">Video</label>
		<input type="file" name="media[video]" value="" id="media_video" />
		<label for="media_thumbnail">Thumbnail</label>
		<input type="file" name="media[thumbnail]" value="" id="media_thumbnail" />
		<input type="submit" value="Upload" />
	</form>


The Sinatra part (assumes the _s3upload_ gem is installed):

	require "s3upload"
	get "/s3upload" do
	  up = S3::Upload.new( options.s3_upload_access_key_id , options.s3_upload_secret_key , options.s3_upload_bucket )
    # Monkey patch allowing a different 'filename' is in the swf,
    # but relies on changing the returned xml from the s3upload gem
	  up.to_xml( params[:key] , params[:contentType] ).gsub('</s3>', "<filename>#{params[:key]}</filename></s3>")
	end
