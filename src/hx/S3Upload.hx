class S3Upload extends flash.display.Sprite {
	
	static var _id : String;
	
	var _signatureURL : String;
	var _prefix : String;
	var _fr : flash.net.FileReference;
	var _fl : flash.net.FileReferenceList;
	var _frs: Hash<flash.net.FileReference>;
	var _filters : Array<flash.net.FileFilter>;
	
	public function new() super()
	
	public function init() {
		_id = stage.loaderInfo.parameters.id;
		_signatureURL = stage.loaderInfo.parameters.signatureURL;
		_prefix = stage.loaderInfo.parameters.prefix;
		_filters = [];
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
		
    		var load			= new flash.net.URLLoader();
    		load.dataFormat		= flash.net.URLLoaderDataFormat.TEXT;
    		load.addEventListener( "complete" , onSignatureComplete );
    		load.addEventListener( "securityError" , onSignatureError );
    		load.addEventListener( "ioError" , onSignatureError );
    		haxe.Timer.delay(function(){ load.load( req ); }, 100+(150*i));
		}
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
	
	function onSignatureError(e) {
		call( "trace" , ["Could not get signature because: " + e.text] );
	}
	
	function onSignatureComplete(e) {
		// Now that we have the signature we can send the file to S3.
		
		var load 			= cast( e.target , flash.net.URLLoader );
		var sign			= new haxe.xml.Fast( Xml.parse( load.data ).firstElement() );
		call("trace", ["loaded sig : " + load.data]);
		if( sign.has.error ) {
			call( "trace" , ["There was an error while making the signature: " + sign.node.error.innerData] );
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
		
		
		var my_fr = _frs.get(opts.key);
		
		var req				= new S3Request( opts );
		req.onError 		= function(msg) { call( "error" , [msg] ); }
		req.onProgress 		= function(p, key) { call( "progress" , [p, key] ); }
		req.onComplete 		= function() { call( "complete" , [opts.key] ); }
		req.upload( my_fr );
		call( "start" , [] );
	}
	
	static function call( eventType , args : Array<Dynamic> = null, array = false ) {
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
		
		var s = new S3Upload();
		flash.Lib.current.addChild( s );
		s.init();
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

class S3Request {
	
	static inline var AMAZON_BASE_URL = "s3.amazonaws.com";
	
	var _opts : S3Options;
	var _httpStatus : Bool;
	
	public var onComplete : Void -> Void;
	public var onProgress : Dynamic;
	public var onError : String -> Void;
	
	public function new( opts : S3Options ) {
		_opts = opts;
		_httpStatus = false;
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
	
	public function upload( fr : flash.net.FileReference ) {
		var url = getUrl();
        flash.system.Security.loadPolicyFile(url + "/crossdomain.xml");
		
		var req = new flash.net.URLRequest( url );
        req.method = flash.net.URLRequestMethod.POST;
        req.data = getVars();            
        
		fr.addEventListener( "uploadCompleteData" , onUploadComplete );
		fr.addEventListener( "securityError" , onUploadError );
		fr.addEventListener( "ioError" , onUploadError );
        fr.addEventListener( "progress" , onUploadProgress);
        fr.addEventListener( "open" , onUploadOpen);
        fr.addEventListener( "httpStatus", onUploadHttpStatus);

        fr.upload(req, "file", false);
	}
	
	function onUploadComplete( e ) {
		if( isError( e.data ) )
			onError( "Amazon S3 returned an error: " + e.data );
		else {
			onProgress( 1, _opts.key);
			onComplete();
		}
	}
	
	function onUploadHttpStatus( e ) {
		_httpStatus = true;
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
		if( !_httpStatus ) // ignore io errors if we already had a valid http status
			onError( "Amazon S3 returned an error: " + e.message );
	}
	
	function isError(responseText:String):Bool {
        return StringTools.startsWith( StringTools.trim( StringTools.replace( responseText , '<?xml version="1.0" encoding="UTF-8"?>' , "" ) ) , "<Error>" );
    }
	
}