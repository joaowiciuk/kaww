//Auto-mining quarry
//converts wood into ores

#include "GenericButtonCommon.as"

const string fuel = "mat_wood";
const string ore = "mat_stone";
const string rare_ore = "mat_gold";

//balance
const int input = 75;					// input cost in fuel
const int stone_amount = 30;
const int initial_output = 100;			// output amount in ore
const int min_output = 50;				// minimal possible output in ore
const int output_decrease = 0;			// by how much output decreases every time ore is dropped
const bool enable_rare = true;			// enable/disable
const int rare_chance = 15;				// one-in
const int rare_output = 25;				// output for rare ore
const int conversion_frequency = 8;	// how often to convert, in seconds

const int min_input = Maths::Ceil(input/initial_output);

//fuel levels for animation
const int max_fuel = 1000;
const int mid_fuel = 500;
const int low_fuel = 250;

//property names
const string fuel_prop = "fuel_level";
const string working_prop = "working";
const string unique_prop = "unique";

void onInit(CSprite@ this)
{
	CSpriteLayer@ belt = this.addSpriteLayer("belt", "QuarryBelt.png", 32, 32);
	if (belt !is null)
	{
		//default anim
		{
			Animation@ anim = belt.addAnimation("default", 0, true);
			int[] frames = {
				0, 1, 2, 3,
				4, 5, 6, 7,
				8, 9, 10, 11,
				12, 13
			};
			anim.AddFrames(frames);
		}
		//belt setup
		belt.SetOffset(Vec2f(-5.0f, -4.0f));
		belt.SetRelativeZ(1);
		belt.SetVisible(true);
	}

	CSpriteLayer@ wood = this.addSpriteLayer("wood", "Quarry.png", 16, 16);
	if (wood !is null)
	{
		wood.SetOffset(Vec2f(11.0f, -1.0f));
		wood.SetVisible(false);
		wood.SetRelativeZ(1);
	}

	this.SetEmitSound("/Quarry.ogg");
	this.SetEmitSoundPaused(true);
}

void onInit(CBlob@ this)
{
	//building properties
	this.set_TileType("background tile", CMap::tile_castle_back);
	this.getSprite().SetZ(-155.0f);
	this.getShape().getConsts().mapCollisions = false;

	//gold building properties
	this.set_s32("gold building amount", 50);

	//quarry properties
	this.set_s16(fuel_prop, 0);
	this.set_bool(working_prop, false);
	this.set_u8(unique_prop, XORRandom(getTicksASecond() * conversion_frequency));

	this.Tag("structure");

	//commands
	this.addCommandID("add fuel");
	string current_output = "current_quarry_output_" + this.getTeamNum();
	CRules@ rules = getRules();

	if (!rules.exists(current_output) || rules.get_s32(current_output) == -1)
	{
		rules.set_s32("current_quarry_output_" + this.getTeamNum(), initial_output);
	}
}

void onTick(CBlob@ this)
{
	//only do "real" update logic on server
	if (getNet().isServer())
	{
		int blobCount = this.get_s16(fuel_prop);

		if ((blobCount >= 50))
		{
			this.set_bool(working_prop, true);

			//only convert every conversion_frequency seconds
			if (getGameTime() % (conversion_frequency * getTicksASecond()) == this.get_u8(unique_prop))
			{
				spawnOre(this);

				if (blobCount - input < min_input)
				{
					this.set_bool(working_prop, false);
				}

				this.Sync(fuel_prop, true);
			}

			this.Sync(working_prop, true);
		}

		if (blobCount < 50)
		{			
			this.set_bool(working_prop, false);
			this.Sync(working_prop, true);
		}
	}

	CSprite@ sprite = this.getSprite();
	if (sprite.getEmitSoundPaused())
	{
		if (this.get_bool(working_prop))
		{
			sprite.SetEmitSoundPaused(false);
		}
	}
	else if (!this.get_bool(working_prop))
	{
		sprite.SetEmitSoundPaused(true);
	}

	//update sprite based on modified or synced properties
	updateWoodLayer(this.getSprite());
	if (getGameTime() % (getTicksASecond()/2) == 0) animateBelt(this, this.get_bool(working_prop));
}

void GetButtonsFor(CBlob@ this, CBlob@ caller)
{
	if (!canSeeButtons(this, caller)) return;

	CBitStream params;
	params.write_u16(caller.getNetworkID());

	if (this.get_s16(fuel_prop) < max_fuel)
	{
		CButton@ button = caller.CreateGenericButton("$mat_wood$", Vec2f(-4.0f, 0.0f), this, this.getCommandID("add fuel"), getTranslatedString("Add fuel"), params);
		if (button !is null)
		{
			button.deleteAfterClick = false;
			button.SetEnabled(caller.hasBlob(fuel, 1));
		}
	}
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID("add fuel"))
	{
		CBlob@ caller = getBlobByNetworkID(params.read_u16());
		if (caller is null) return;

		//amount we'd _like_ to insert
		int requestedAmount = Maths::Min(250, max_fuel - this.get_s16(fuel_prop));
		//(possible with laggy commands from 2 players, faster to early out here if we can)
		if (requestedAmount <= 0) return;

		CBlob@ carried = caller.getCarriedBlob();
		//how much fuel does the caller have including what's potentially in his hand?
		int callerQuantity = caller.getInventory().getCount(fuel) + (carried !is null && carried.getName() == fuel ? carried.getQuantity() : 0);

		//amount we _can_ insert
		int ammountToStore = Maths::Min(requestedAmount, callerQuantity);
		//can we even insert anything?
		if (ammountToStore > 0)
		{
			caller.TakeBlob(fuel, ammountToStore);
			this.set_s16(fuel_prop, this.get_s16(fuel_prop) + ammountToStore);

			updateWoodLayer(this.getSprite());

			this.getSprite().PlaySound("hit_wood.ogg");
		}
	}
}

void spawnOre(CBlob@ this)
{
	int blobCount = this.get_s16(fuel_prop);
	int actual_input = Maths::Min(input, blobCount);

	int r = XORRandom(rare_chance);
	int output = getRules().get_s32("current_quarry_output_" + this.getTeamNum());

	//rare chance, but never rare if not a full batch of wood
	bool rare = (enable_rare && r == 0 && blobCount >= input);

	CBlob@ _ore = server_CreateBlobNoInit(!rare ? ore : rare_ore);

	if (_ore is null) return;

	int amountToSpawn = Maths::Floor(output * actual_input / input);
	//round to 5
	int remainder = amountToSpawn % 5;
	amountToSpawn += (remainder < 3 ? -remainder : (5 - remainder));
	//setup res
	_ore.Tag("custom quantity");
	_ore.Init();
	_ore.setPosition(this.getPosition() + Vec2f(-4.0f, 0.0f));
	_ore.server_SetQuantity(!rare ? stone_amount : rare_output);

	this.set_s16(fuel_prop, blobCount - actual_input); //burn wood
	const string current_output = "current_quarry_output_" + this.getTeamNum();
	
	// reduce output if it's higher than minimal output
	if (getRules().hasScript("ResetQuarry.as"))
	{
		getRules().set_s32(current_output, Maths::Max(getRules().get_s32(current_output) - output_decrease, min_output));
	}
}

void updateWoodLayer(CSprite@ this)
{
	int wood = this.getBlob().get_s16(fuel_prop);
	CSpriteLayer@ layer = this.getSpriteLayer("wood");

	if (layer is null) return;

	if (wood < min_input)
	{
		layer.SetVisible(false);
	}
	else
	{
		layer.SetVisible(true);
		int frame = 5;
		if (wood > low_fuel) frame = 6;
		if (wood > mid_fuel) frame = 7;
		layer.SetFrameIndex(frame);
	}
}

void animateBelt(CBlob@ this, bool isActive)
{
	//safely fetch the animation to modify
	CSprite@ sprite = this.getSprite();
	if (sprite is null) return;
	CSpriteLayer@ belt = sprite.getSpriteLayer("belt");
	if (belt is null) return;
	Animation@ anim = belt.getAnimation("default");
	if (anim is null) return;

	//modify it based on activity
	if (isActive)
	{
		// slowly start animation
		if (anim.time == 0) anim.time = 6;
		if (anim.time > 3) anim.time--;
	}
	else
	{
		//(not tossing stone)
		if (anim.frame < 2 || anim.frame > 8)
		{
			// slowly stop animation
			if (anim.time == 6) anim.time = 0;
			if (anim.time > 0 && anim.time < 6) anim.time++;
		}
	}
}

void onRender(CSprite@ this)
{
	if (g_videorecording)
		return;

	CBlob@ blob = this.getBlob();
	Vec2f center = blob.getPosition();
	Vec2f mouseWorld = getControls().getMouseWorldPos();
	const f32 renderRadius = (blob.getRadius()) * 0.95f;
	bool mouseOnBlob = (mouseWorld - center).getLength() < renderRadius;
	if (mouseOnBlob)
	{
		//VV right here VV
		Vec2f pos2d = blob.getScreenPos() + Vec2f(0, 30);
		Vec2f dim = Vec2f(24, 8);
		const f32 y = blob.getHeight() * 2.4f;
		const f32 perc = blob.get_s16(fuel_prop)/1000.0f ;
		
		GUI::DrawRectangle(Vec2f(pos2d.x - dim.x - 2, pos2d.y + y - 2), Vec2f(pos2d.x + dim.x + 2, pos2d.y + y + dim.y + 2));
		GUI::DrawRectangle(Vec2f(pos2d.x - dim.x + 2, pos2d.y + y + 2), Vec2f(pos2d.x - dim.x + perc * 2.0f * dim.x - 2, pos2d.y + y + dim.y - 2), SColor(0xff8bbc7e));

		//GUI::SetFont("menu");
		//GUI::DrawText("Wood: " + blob.get_s16(fuel_prop), Vec2f(pos2d.x - dim.x - 7, pos2d.y + y + 9), color_white);
	}
}

f32 onHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
	if (hitterBlob.hasTag("grenade") || hitterBlob.getName() == "c4")
	{
		return damage * 3.0f;
	}
	return damage;
}
