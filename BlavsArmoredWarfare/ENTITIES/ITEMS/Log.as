#include "Hitters.as"

const bool dangerous_logs = false;

void onInit(CSprite@ this)
{
	this.animation.frame = XORRandom(4);

	this.getCurrentScript().runFlags |= Script::remove_after_this;
}

void onInit(CBlob@ this)
{
	if (getNet().isServer())
	{
		this.server_SetTimeToDie(240 + XORRandom(60));

		this.server_setTeamNum(-1);

		dictionary harvest;
		harvest.set('mat_wood', 40);
		this.set('harvest', harvest);
	}

	this.Tag("pushedByDoor");
}

//collide with vehicles and structures	- hit stuff if thrown

bool doesCollideWithBlob(CBlob@ this, CBlob@ blob)
{
	bool thrown = false;
	CPlayer @p = this.getDamageOwnerPlayer();
	CPlayer @bp = blob.getPlayer();
	if (p !is null && bp !is null && p.getTeamNum() != bp.getTeamNum())
	{
		thrown = true;
	}
	return (blob.getShape().isStatic() || (blob.isInWater() && blob.hasTag("vehicle")) ||
	        (dangerous_logs && this.hasTag("thrown") && blob.hasTag("flesh") && thrown)); // boat
}

void onDetach(CBlob@ this, CBlob@ detached, AttachmentPoint@ attachedPoint)
{
	if (dangerous_logs)
	{
		this.Tag("thrown");
		this.SetDamageOwnerPlayer(detached.getPlayer());
		//	printf("thrown");
	}
}

f32 onHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
	if (isServer() && XORRandom(10) == 0 && hitterBlob !is null
	&& hitterBlob.getName() == "slave" && hitterBlob.getPlayer() !is null)
	{
		u8 exp_reward = XORRandom(2)+1;
		CBitStream params;
		params.write_u8(exp_reward);

		getRules().add_u32(hitterBlob.getPlayer().getUsername() + "_exp", exp_reward);
		getRules().Sync(hitterBlob.getPlayer().getUsername() + "_exp", true);
		hitterBlob.server_SendCommandToPlayer(hitterBlob.getCommandID("addxp_universal"), params, hitterBlob.getPlayer());
	}
	return damage;
}

void onCollision(CBlob@ this, CBlob@ blob, bool solid)
{
	if (dangerous_logs && this.hasTag("thrown"))
	{
		if (blob is null || !blob.hasTag("flesh"))
		{
			return;

		}

		CPlayer@ player = this.getDamageOwnerPlayer();
		if (player !is null && player.getTeamNum() != blob.getTeamNum())
		{
			const f32 dmg = this.getShape().vellen * 0.25f;
			if (dmg > 1.5f)
			{
				//	printf("un thrown " + dmg);
				this.server_Hit(blob, this.getPosition(), this.getVelocity(), dmg, Hitters::flying, false);  // server_Hit() is server-side only
			}
			this.Untag("thrown");
		}
	}
}
