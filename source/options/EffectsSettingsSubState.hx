package options;

import objects.Character;

class EffectsSettingsSubState extends BaseOptionsMenu
{
	var antialiasingOption:Int;
	var boyfriend:Character = null;
	public function new()
	{
		title = Language.getPhrase('effects_menu', 'EfeCtS Settings');
		rpcTitle = 'Fuck U'; //for Discord Rich Presence
		
		
		boyfriend = new Character(840, 170, 'bf', true);
		boyfriend.visible = false;
		boyfriend.setGraphicSize(Std.int(boyfriend.width * 0.75));
		boyfriend.updateHitbox();
		
		if(!ClientPrefs.data.animation)
		{
		boyfriend.dance();
		boyfriend.animation.finishCallback = function (name:String) boyfriend.dance();
		boyfriend.visible = false;
		}
		 else boyfriend.visible = true;
	
		var option:Option = new Option('Transparentacy', //Name
			'If checked, Makes the Hud and UI slightly see through', //Description
			'Transparent', //Save data variable name
			BOOL); //Variable type
		addOption(option);

		var option:Option = new Option('animation',
			'If unchecked, some animation. Only use this if you have a piece of shit PC., or if you spend your life on a fucking potato',
			'animation',
			BOOL);
		option.onChange = onChangeAntiAliasing; //Changing onChange is only needed if you want to make a special interaction after it changes the value
		addOption(option);
		antialiasingOption = optionsArray.length-1;

		super();
		insert(1, boyfriend);
	}

	function onChangeAntiAliasing()
	{
		for (sprite in members)
		{
			var sprite:FlxSprite = cast sprite;
			if(sprite != null && (sprite is FlxSprite) && !(sprite is FlxText)) {
				sprite.antialiasing = ClientPrefs.data.antialiasing;
			}
		}
	}

	function onChangeFramerate()
	{
		if(ClientPrefs.data.framerate > FlxG.drawFramerate)
		{
			FlxG.updateFramerate = ClientPrefs.data.framerate;
			FlxG.drawFramerate = ClientPrefs.data.framerate;
		}
		else
		{
			FlxG.drawFramerate = ClientPrefs.data.framerate;
			FlxG.updateFramerate = ClientPrefs.data.framerate;
		}
	}

	override function changeSelection(change:Int = 0)
	{
		super.changeSelection(change);
		boyfriend.visible = (antialiasingOption == curSelected);
	}
}