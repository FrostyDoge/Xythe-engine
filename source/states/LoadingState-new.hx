package;

import flixel.addons.display.FlxBackdrop;
import flixel.addons.display.FlxTiledSprite;
import openfl.filters.ShaderFilter;
import lime.app.Promise;
import lime.app.Future;
import flixel.FlxG;
import flixel.FlxState;
import flixel.FlxSprite;
import flixel.ui.FlxBar;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.util.FlxTimer;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.math.FlxMath;
import flixel.system.FlxSound;
import flixel.text.FlxText;
import flixel.util.FlxColor;

import openfl.utils.Assets;
import lime.utils.Assets as LimeAssets;
import lime.utils.AssetLibrary;
import lime.utils.AssetManifest;

import haxe.io.Path;

using StringTools;

class AsyncAssetPreloader
{
	var characters:Array<String> = [];
	var audio:Array<String> = [];

	var onComplete:Void->Void = null;

	public var percent(get, default):Float = 0;
	private function get_percent()
	{
		if (totalLoadCount > 0)
		{
			percent = loadedCount/totalLoadCount;
		}

		return percent;
	}
	public var totalLoadCount:Int = 0;
	public var loadedCount:Int = 0;

	public function new(onComplete:Void->Void)
	{
		this.onComplete = onComplete;
		generatePreloadList();
	}

	private function generatePreloadList()
	{
		if (PlayState.SONG != null){
			characters.push(PlayState.SONG.player1);
			characters.push(PlayState.SONG.player2);
			characters.push(PlayState.SONG.gfVersion);

			audio.push(Paths.inst(PlayState.SONG.song));
			if (PlayState.SONG.needsVoices)
				audio.push(Paths.voices(PlayState.SONG.song));

			var events:Array<Dynamic> = [];
            var eventStr:String = '';
            var eventNoticed:String = '';

            if(PlayState.SONG.events.length > 0)
            {
                for(event in PlayState.SONG.events)
                {
                    for (i in 0...event[1].length)
                        {
                            eventStr = event[1][i][0].toLowerCase();
                            eventNoticed = event[1][i][2];
                        }
                    events.push(event);
                }
            }

			totalLoadCount = audio.length + characters.length-1; //do -1 because it will be behind at the end when theres a small freeze
		}
	}

	public function load(async:Bool = true)
	{
		if (async)
		{
			trace('loading async');

		
			var multi:Bool = false;

			if (multi) //sometimes faster, sometimes slower, wont bother using it
			{
				setupFuture(function()
				{
					loadAudio();
					return true;
				});
				setupFuture(function()
				{
					loadCharacters();
					return true;
				});
			}
			else 
			{
				setupFuture(function()
				{
					loadAudio();
					loadCharacters();	
					return true;
				});
			}


		}
		else 
		{
			loadAudio();
			loadCharacters();
			finish();
		}
	}
	function setupFuture(func:Void->Bool)
	{
		var fut:Future<Bool> = new Future(func, true);
		fut.onComplete(function(ashgfjkasdfhkjl) {
			finish();
		});
		fut.onError(function(_) {
			finish(); //just continue anyway who cares
		});
		totalFinishes++;
	}
	var totalFinishes:Int = 0;
	var finshCount:Int = 0;
	private function finish()
	{
		finshCount++;
		if (finshCount < totalFinishes)
			return;

		if (onComplete != null)
			onComplete();
	}
	public function loadAudio()
	{
		for (i in audio)
		{
			loadedCount++;
			new FlxSound().loadEmbedded(i);
		}
		trace('loaded audio');
	}
	public function loadCharacters()
	{
		for (i in characters)
		{
			loadedCount++;
			new Character(0,0, i);
		}
		trace('loaded characters');
	}



}

class LoadingState extends MusicBeatState
{
	inline static var MIN_TIME = 1.0;

	// Browsers will load create(), you can make your song load a custom directory there
	// If you're compiling to desktop (or something that doesn't use NO_PRELOAD_ALL), search for getNextState instead
	// I'd recommend doing it on both actually lol
	
	// TO DO: Make this easier
	var target:FlxState;
	var stopMusic = false;
	var directory:String;
	var callbacks:MultiCallback;

	var loader:AsyncAssetPreloader = null;
	var lerpedPercent:Float = 0;
	var loadTime:Float = 0;
	var loadingText:FlxText;

	var continueText:FlxText;

	var targetShit:Float = 0;

	public var loaderStuff:Array<Dynamic> = [false, 0.7];

	public function new(target:FlxState, stopMusic:Bool, directory:String, ?isBlack:Bool = false, ?time:Float = 0.7)
	{
		super();
		this.target = target;
		this.stopMusic = stopMusic;
		this.directory = directory;

		loaderStuff[0] = isBlack;
		loaderStuff[1] = time;
	}

	var funkay:FlxSprite;
	var loadingBar:FlxBar;
	override public function create()
	{
		var bg:FlxSprite = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, 0x00caff4d);
		add(bg);
		funkay = new FlxSprite(0, 0).loadGraphic(Paths.getPath('images/funkay.png', IMAGE));
		funkay.setGraphicSize(0, FlxG.height);
		funkay.updateHitbox();
		funkay.antialiasing = ClientPrefs.globalAntialiasing;
		// add(funkay);
		funkay.scrollFactor.set();
		funkay.screenCenter();

		loader = new AsyncAssetPreloader(function()
		{
			trace("Load time: " + loadTime);
			new FlxTimer().start(1.0, function(tmr:FlxTimer) {
				onLoad();
			});
		});
		loader.load(true);

		loadingBar = new FlxBar(0, FlxG.height-25, LEFT_TO_RIGHT, FlxG.width, 25, this, 'lerpedPercent', 0, 1);
		loadingBar.scrollFactor.set();
		loadingBar.createFilledBar(0xFF000000, 0xFFFFFFFF);
		add(loadingBar);

		loadingText = new FlxText(2, FlxG.height-25-30, 0, "Loading...");
		loadingText.setFormat(Paths.font("DEADLY KILLERS.ttf"), 24, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(loadingText);

		initSongsManifest().onComplete
		(
			function (lib)
			{
				callbacks = new MultiCallback(()->{});
				var introComplete = callbacks.add("introComplete");
				/*if (PlayState.SONG != null) {
					checkLoadSong(getSongPath());
					if (PlayState.SONG.needsVoices)
						checkLoadSong(getVocalPath());
				}*/
				checkLibrary("shared");
				if(directory != null && directory.length > 0 && directory != 'shared') {
					checkLibrary(directory);
				}

				var fadeTime = 0.5;
				new FlxTimer().start(fadeTime + MIN_TIME, function(_) introComplete());
			}
		);
	}
	
	function checkLoadSong(path:String)
	{
		if (!Assets.cache.hasSound(path))
		{
			var library = Assets.getLibrary("songs");
			final symbolPath = path.split(":").pop();
			// @:privateAccess
			// library.types.set(symbolPath, SOUND);
			// @:privateAccess
			// library.pathGroups.set(symbolPath, [library.__cacheBreak(symbolPath)]);
			var callback = callbacks.add("song:" + path);
			Assets.loadSound(path).onComplete(function (_) { callback(); });
		}
	}
	
	function checkLibrary(library:String) {
		trace(Assets.hasLibrary(library));
		if (Assets.getLibrary(library) == null)
		{
			@:privateAccess
			if (!LimeAssets.libraryPaths.exists(library))
				throw "Missing library: " + library;

			var callback = callbacks.add("library:" + library);
			Assets.loadLibrary(library).onComplete(function (_) { callback(); });
		}
	}
	
	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (loader != null)
		{
			loadTime += elapsed;
			lerpedPercent = FlxMath.lerp(lerpedPercent, loader.percent, elapsed*8);
			loadingText.text = "Loading... (" + loader.loadedCount + "/" + (loader.totalLoadCount+1) + ")";
		}
	}
	
	function onLoad()
	{
		if (stopMusic && FlxG.sound.music != null)
			FlxG.sound.music.stop();
		
		MusicBeatState.switchState(target, loaderStuff[0], loaderStuff[1]);
	}
	
	static function getSongPath()
	{
		return Paths.inst(PlayState.SONG.song);
	}
	
	static function getVocalPath()
	{
		return Paths.voices(PlayState.SONG.song);
	}
	
	inline static public function loadAndSwitchState(target:FlxState, stopMusic = false, ?isBlack:Bool = false, ?time:Float = 0.7)
	{
		MusicBeatState.switchState(getNextState(target, stopMusic, isBlack, time), isBlack, time);
	}
	
	static function getNextState(target:FlxState, stopMusic = false, ?isBlack:Bool = false, ?time:Float = 0.7):FlxState
	{
		var directory:String = 'shared';
		var weekDir:String = StageData.forceNextDirectory;
		StageData.forceNextDirectory = null;

		if(weekDir != null && weekDir.length > 0 && weekDir != '') directory = weekDir;

		Paths.setCurrentLevel(directory);
		trace('Setting asset folder to ' + directory);

		
		var loaded:Bool = false;
		if (PlayState.SONG != null) {
			loaded = isSoundLoaded(getSongPath()) && (!PlayState.SONG.needsVoices || isSoundLoaded(getVocalPath())) && isLibraryLoaded("shared") && isLibraryLoaded(directory);
		}
		
		if (!loaded)
			return new LoadingState(target, stopMusic, directory, isBlack, time);

		if (stopMusic && FlxG.sound.music != null)
			FlxG.sound.music.stop();
		
		return target;
	}
	
	static function isSoundLoaded(path:String):Bool
	{
		return Assets.cache.hasSound(path);
	}
	
	static function isLibraryLoaded(library:String):Bool
	{
		return Assets.getLibrary(library) != null;
	}
	
	override function destroy()
	{
		super.destroy();
		
		callbacks = null;
	}
	
	static function initSongsManifest()
	{
		var id = "songs";
		var promise = new Promise<AssetLibrary>();

		var library = LimeAssets.getLibrary(id);

		if (library != null)
		{
			return Future.withValue(library);
		}

		var path = id;
		var rootPath = null;

		@:privateAccess
		var libraryPaths = LimeAssets.libraryPaths;
		if (libraryPaths.exists(id))
		{
			path = libraryPaths[id];
			rootPath = Path.directory(path);
		}
		else
		{
			if (StringTools.endsWith(path, ".bundle"))
			{
				rootPath = path;
				path += "/library.json";
			}
			else
			{
				rootPath = Path.directory(path);
			}
			@:privateAccess
			path = LimeAssets.__cacheBreak(path);
		}

		AssetManifest.loadFromFile(path, rootPath).onComplete(function(manifest)
		{
			if (manifest == null)
			{
				promise.error("Cannot parse asset manifest for library \"" + id + "\"");
				return;
			}

			var library = AssetLibrary.fromManifest(manifest);

			if (library == null)
			{
				promise.error("Cannot open library \"" + id + "\"");
			}
			else
			{
				@:privateAccess
				LimeAssets.libraries.set(id, library);
				library.onChange.add(LimeAssets.onChange.dispatch);
				promise.completeWith(Future.withValue(library));
			}
		}).onError(function(_)
		{
			promise.error("There is no asset library with an ID of \"" + id + "\"");
		});

		return promise.future;
	}
}

class MultiCallback
{
	public var callback:Void->Void;
	public var logId:String = null;
	public var length(default, null) = 0;
	public var numRemaining(default, null) = 0;
	
	var unfired = new Map<String, Void->Void>();
	var fired = new Array<String>();
	
	public function new (callback:Void->Void, logId:String = null)
	{
		this.callback = callback;
		this.logId = logId;
	}
	
	public function add(id = "untitled")
	{
		id = '$length:$id';
		length++;
		numRemaining++;
		var func:Void->Void = null;
		func = function ()
		{
			if (unfired.exists(id))
			{
				unfired.remove(id);
				fired.push(id);
				numRemaining--;
				
				if (logId != null)
					log('fired $id, $numRemaining remaining');
				
				if (numRemaining == 0)
				{
					if (logId != null)
						log('all callbacks fired');
					callback();
				}
			}
			else
				log('already fired $id');
		}
		unfired[id] = func;
		return func;
	}
	
	inline function log(msg):Void
	{
		if (logId != null)
			trace('$logId: $msg');
	}
	
	public function getFired() return fired.copy();
	public function getUnfired() return [for (id in unfired.keys()) id];
}