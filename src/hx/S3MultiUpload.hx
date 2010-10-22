class S3MultiUpload extends flash.display.Sprite {
	
	static var _id : String;
	
	var _signatureURL : String;
	var _prefix : String;
	var _fr : flash.net.FileReference;
	var _fl : flash.net.FileReferenceList;
	var _frs: Hash<flash.net.FileReference>;
	var _filters : Array<flash.net.FileFilter>;
	var _uploader : S3UploadQueue;
	var _queue_size : Int;
	
	public function new() super()
	
	public function init() {
		_id = stage.loaderInfo.parameters.id;
		_signatureURL = stage.loaderInfo.parameters.signatureURL;
		_prefix = stage.loaderInfo.parameters.prefix;
		_filters = [];
		if( stage.loaderInfo.parameters.queue_size != null && stage.loaderInfo.parameters.queue_size != "" ) {
			_queue_size = Std.parseInt(stage.loaderInfo.parameters.queue_size);
		}
		else{
			_queue_size = 5;
		}
		if( stage.loaderInfo.parameters.filters != null && stage.loaderInfo.parameters.filters != "" ) {
			for( filter in stage.loaderInfo.parameters.filters.split("|") ) {
				var f = filter.split("#");
				_filters.push( new flash.net.FileFilter( f[0] , f[1] ) );
			}
		}
		
		if( flash.external.ExternalInterface.available ) {
			flash.external.ExternalInterface.addCallback( "disable" , disable );
			flash.external.ExternalInterface.addCallback( "enable" , enable );
			flash.external.ExternalInterface.addCallback( "upload" , upload );
		}
		stage.addEventListener( "resize" , onStageResize );
		onStageResize();
		enable();
	}
	
	function onBrowse( e ) {
		var fl = new flash.net.FileReferenceList();
		_frs = new Hash<flash.net.FileReference>();
		fl.addEventListener( "cancel" , function(e) { call( e.type , [] ); } );
		fl.addEventListener( "select" , function(e) { 
		    var foo = [];
		    for (bar in fl.fileList){foo.push([bar.name,bar.size,extractType(bar)]);}
		    call( e.type , foo, true); 
		} );
		if( _filters.length > 0 )
			fl.browse( _filters );
		else
			fl.browse();
		_fl = fl;
	}
	
	function enable() {
		buttonMode = true;
		doubleClickEnabled = true;
		addEventListener( "click" , onBrowse );
		addEventListener( "click" , onMouseEvent );
		addEventListener( "rollOver" , onMouseEvent );
		addEventListener( "rollOut" , onMouseEvent );
		addEventListener( "mouseMove" , onMouseEvent );
		addEventListener( "mouseDown" , onMouseEvent );
		addEventListener( "mouseUp" , onMouseEvent );
		addEventListener( "mouseOver" , onMouseEvent );
		addEventListener( "mouseOut" , onMouseEvent );
		addEventListener( "doubleClick" , onMouseEvent );
		call("enabled");
	}
	
	function disable() {
		buttonMode = false;
		doubleClickEnabled = false;
		removeEventListener( "click" , onBrowse );
		removeEventListener( "click" , onMouseEvent );
		removeEventListener( "rollOver" , onMouseEvent );
		removeEventListener( "rollOut" , onMouseEvent );
		removeEventListener( "mouseMove" , onMouseEvent );
		removeEventListener( "mouseDown" , onMouseEvent );
		removeEventListener( "mouseUp" , onMouseEvent );
		removeEventListener( "mouseOver" , onMouseEvent );
		removeEventListener( "mouseOut" , onMouseEvent );
		removeEventListener( "doubleClick" , onMouseEvent );
		call("disabled");
	}
	
	function onMouseEvent(e) {
		call( "mouseevent" , [e.type.toLowerCase(),e.stageX,e.stageY] );
	}
	
	function upload() {
		// No browse has been called
		if( _fl == null )
			return;
		var my_fr;
		var i = 0;
		_frs = new Hash();
		_uploader = new S3UploadQueue(this, _queue_size);
		
		for ( my_fr in _fl.fileList){
            _fr = my_fr;
            i++;
			// Fetch a signature and other good things from the backend
			var vars 			= new flash.net.URLVariables();
			vars.fileName 		= my_fr.name;
			vars.fileSize 		= my_fr.size;
			vars.contentType	= extractType( my_fr );
			vars.key 			= _prefix + my_fr.name;
			
			if(_frs.exists(vars.key)){
				continue;
			}
			
			_frs.set(vars.key, my_fr);
			var req 			= new flash.net.URLRequest(_signatureURL);
			req.method			= flash.net.URLRequestMethod.GET;
			req.data			= vars;
			_uploader.queue(req);
			
		}
		_uploader.start();
	}
	
	static function extractType( fr : flash.net.FileReference ) {
		if( fr.type == null || fr.type.indexOf( "/" ) == -1 ) {
			var ext = fr.name.split(".").pop();
			var mime = new MimeTypes().getMimeType( ext );
			if( mime == null )
				return "application/octet-stream";
			else
				return mime;
		}
		return fr.type;
	}
	
	
	public static function call( eventType , args : Array<Dynamic> = null, array = false ) {
		if( args == null ) 
			args = [];
		var method = "on"+eventType;
		if( _id != null && flash.external.ExternalInterface.available ) {
			var c;
			if(array){
				var new_args = [];
				var arg;
				
				for (arg in args){
					new_args.push("['"+arg.join("','")+"']");
				}
				c = "function(){
					var swf = document.getElementById('"+_id+"');
					if( swf )
						swf['"+method+"'].apply(swf,["+new_args.join(",")+"]);
				}()";
			}
			else{
				c = "function(){
					var swf = document.getElementById('"+_id+"');
					if( swf )
						swf['"+method+"'].apply(swf,['"+args.join("','")+"']);
				}()";
			}
			flash.external.ExternalInterface.call( c , [] );
		}
	}
	
	function onStageResize(e=null) {
		graphics.clear();
		graphics.beginFill( 0 , 0 );
		graphics.drawRect( 0 , 0 , stage.stageWidth , stage.stageHeight );
	}
	
	public static function main() {
		flash.Lib.current.stage.align = flash.display.StageAlign.TOP_LEFT;
		flash.Lib.current.stage.scaleMode = flash.display.StageScaleMode.NO_SCALE;
		
		var s = new S3MultiUpload();
		flash.Lib.current.addChild( s );
		s.init();
	}
	
	public function files(){
		return _frs;
	}
}

typedef S3Options = {
	var accessKeyId : String;
	var acl : String;
	var bucket : String;
	var contentType : String;
	var expires : String;
	var key : String;
	var secure : Bool;
	var signature : String;
	var policy : String;
}

class S3UploadQueue {
	var _requests : Array<S3Request>;
	var _signature_requests : Array<flash.net.URLRequest>;
	var _request_timer : haxe.Timer;
	var _sigloader : flash.net.URLLoader;
	var _parent : S3MultiUpload;
	public var max_requests : Int;
	public var request_count : Int;
	
	public function new(parent, max_r = 5) {
		_parent = parent;
		_signature_requests = new Array<flash.net.URLRequest>();
		_requests = new Array<S3Request>();
		request_count = 0;
		max_requests = max_r;
		_sigloader = new flash.net.URLLoader();
		_sigloader.dataFormat = flash.net.URLLoaderDataFormat.TEXT;
		_sigloader.addEventListener( "complete" , onSignatureComplete );
		_sigloader.addEventListener( "securityError" , onSignatureError );
		_sigloader.addEventListener( "ioError" , onSignatureError );
	}
	
	public function start(){
		_request_timer = new haxe.Timer(100);
		_request_timer.run = dequeue;
	}
	
	public function queue(new_request : flash.net.URLRequest) {
		
		_signature_requests.push(new_request);
	}
	
	public function dequeue() {
		if(request_count < max_requests){
			if( _requests.length > 0 ){
				next_upload();
			}
			else if( _signature_requests.length > 0 ){
				next_sig();
			}
		}
		if( _requests.length == 0 && _signature_requests.length == 0 && request_count == 0){
			_request_timer.stop();
			_request_timer = null;
		}
	}
	
	function next_sig(){
		if( _signature_requests.length > 0 ){
			var req = _signature_requests.shift();
			increment();
			_sigloader.load( req );
		}
	}
	
	function next_upload(){
		if( _requests.length > 0 ){
			var req = _requests.shift();
			increment();
			req.upload( );
			S3MultiUpload.call( "start" , [] );
		}
	}
	
	
	function onSignatureError(e) {
		S3MultiUpload.call( "trace" , ["Could not get signature because: " + e.text] );
		decrement();
	}
	
	function onSignatureComplete(e) {
		// Now that we have the signature we can send the file to S3.
		
		decrement();
		var load 			= cast( e.target , flash.net.URLLoader );
		var sign			= new haxe.xml.Fast( Xml.parse( load.data ).firstElement() );
		S3MultiUpload.call("trace", ["loaded sig : " + load.data]);
		if( sign.has.error ) {
			S3MultiUpload.call( "trace" , ["There was an error while making the signature: " + sign.node.error.innerData] );
			return;
		}
		
		// Create an S3Options object from the signature xml
		var opts 			= {
			accessKeyId: sign.node.accessKeyId.innerData,
			acl: sign.node.acl.innerData,
			bucket: sign.node.bucket.innerData,
			contentType: sign.node.contentType.innerData,
			expires: sign.node.expires.innerData,
			key: sign.node.key.innerData,
			secure: sign.node.secure.innerData == "true",
			signature: sign.node.signature.innerData,
			policy: sign.node.policy.innerData
		};
		
		
		var my_fr = _parent.files().get(opts.key);
		
		var req				= new S3Request( opts, this );
		req.onError 		= function(msg) { S3MultiUpload.call( "error" , [msg] ); }
		req.onProgress 		= function(p, key) { S3MultiUpload.call( "progress" , [p, key] ); }
		req.onComplete 		= function() { S3MultiUpload.call( "complete" , [opts.key] ); }
		req.file = my_fr;
		
		_requests.push(req);
	}
	
	public function increment(){
		request_count++;
	}
	
	public function decrement(){
		request_count--;
		if(request_count < 0){
			request_count = 0;
		}
	}
}

class S3Request {
	
	static inline var AMAZON_BASE_URL = "s3.amazonaws.com";
	
	var _opts : S3Options;
	var _httpStatus : Bool;
	var _queue : S3UploadQueue;
	
	public var onComplete : Void -> Void;
	public var onProgress : Dynamic;
	public var onError : String -> Void;
	public var file : flash.net.FileReference;
	
	public function new( opts : S3Options , queue : S3UploadQueue) {
		_opts = opts;
		_httpStatus = false;
		_queue = queue;
	}
	
	function getUrl() {
		var vanity = canUseVanityStyle();
		
		if( _opts.secure && vanity && _opts.bucket.indexOf( "." ) > -1 )
			throw new flash.errors.IllegalOperationError( "Cannot use SSL with bucket name containing '.': " + _opts.bucket );
			
		var url = "http" + ( _opts.secure ? "s" : "" ) + "://";
		
		if( vanity )
			url += _opts.bucket + "." + AMAZON_BASE_URL;
		else
			url += AMAZON_BASE_URL + "/" + _opts.bucket;
			
		return url;
	}
	
	function getVars() {
		var vars 			 = new flash.net.URLVariables();
        vars.key             = _opts.key;
        vars.acl             = _opts.acl;
        vars.AWSAccessKeyId  = _opts.accessKeyId;
        vars.signature       = _opts.signature;
		Reflect.setField( vars , "Content-Type" , _opts.contentType );
        vars.policy          = _opts.policy;
        vars.success_action_status = "201";
		return vars;
	}
	
	function canUseVanityStyle() {
		if( _opts.bucket.length < 3 || _opts.bucket.length > 63 )
			return false;
		
		var periodPosition = _opts.bucket.indexOf( "." );
		if( periodPosition == 0 && periodPosition == _opts.bucket.length - 1 )
			return false;
			
		if( ~/^[0-9]|+\.[0-9]|+\.[0-9]|+\.[0-9]|+$/.match( _opts.bucket ) )
			return false;
		
		if( _opts.bucket.toLowerCase() != _opts.bucket )
			return false;
		
		return true;
	}
	
	public function upload() {
		
		var url = getUrl();
        flash.system.Security.loadPolicyFile(url + "/crossdomain.xml");
		
		var req = new flash.net.URLRequest( url );
        req.method = flash.net.URLRequestMethod.POST;
        req.data = getVars();            
        
		file.addEventListener( "uploadCompleteData" , onUploadComplete );
		file.addEventListener( "securityError" , onUploadError );
		file.addEventListener( "ioError" , onUploadError );
        file.addEventListener( "progress" , onUploadProgress);
        file.addEventListener( "open" , onUploadOpen);
        file.addEventListener( "httpStatus", onUploadHttpStatus);

        file.upload(req, "file", false);
	}
	
	function onUploadComplete( e ) {
		if( isError( e.data ) )
			onError( "Amazon S3 returned an error: " + e.data );
		else {
			onProgress( 1, _opts.key);
			onComplete();
		}
		_queue.decrement();
	}
	
	function onUploadHttpStatus( e ) {
		_httpStatus = true;
		_queue.decrement();
		if( e.status >= 200 && e.status < 300 )
			onComplete();
		else
			onError( "Amazon S3 returned an error: " + e.status + ' - ' + e.data );
	}
	
	function onUploadOpen( e ) {
		onProgress( 0, _opts.key );
	}
	
	function onUploadProgress( e ) {
		onProgress( e.bytesLoaded / e.bytesTotal, _opts.key);
	}
	
	function onUploadError( e ) {
		if( !_httpStatus ){// ignore io errors if we already had a valid http status
			onError( "Amazon S3 returned an error: " + e.message );
			_queue.decrement();
		}
	}
	
	function isError(responseText:String):Bool {
        return StringTools.startsWith( StringTools.trim( StringTools.replace( responseText , '<?xml version="1.0" encoding="UTF-8"?>' , "" ) ) , "<Error>" );
    }
	
}