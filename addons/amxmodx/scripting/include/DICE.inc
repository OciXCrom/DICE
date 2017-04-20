#if defined _DICE_included
    #endinput
#endif

#define _DICE_included

#define PLUGIN_VERSION "1.1"
#define RANDOM_COLOR random_num(50, 255)

enum _:ItemTypes
{
	ITEM_INSTANT = 0,
	ITEM_DELAYED
}

enum _:CvarTypes
{
	CVAR_INTEGER = 0,
	CVAR_FLOAT,
	CVAR_STRING
}

native AddDiceItem(plugin[], name[], type, chatmessage[], startfunc[], hudmessage[] = "", minduration = 0, maxduration = 0, bool:glow = true)
native AddDiceCvar(item[], option[], value[], type = CVAR_INTEGER)
native AddDiceResource(item[], resource[])
native any:GetDiceCvar(cvar, type = CVAR_INTEGER, buffer[] = "", len = 0)
native DiceHUD(message[])
native DiceDHUD(id, message[])
native DiceChat(id, message[], any:...)
native bool:IsDiceActive()