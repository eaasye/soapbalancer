#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>

public Plugin myinfo = {                                                                                                                                                         
        name = "[TF2] Team Balance",
        author = "easye",
        description = "Balances teams, intended for soap dm",
        version = "1.0.1",
        url=""
}

enum struct PlayerSwap {
	int largerPlayer;
	int smallerPlayer;
	TFTeam largerTeam;
	TFTeam smallerTeam;
	TFClassType largerClass;
	TFClassType smallerClass;
}

//0 = damage, 1 = old frags, 2 = old damage, 3 = skip ResetHeartBeat, 4 = old team
ConVar soapPercent, soapInterval, soapEnabled;
Handle HeartBeat;
int playerArray[MAXPLAYERS][5];
bool skipHeartBeat = false;


public void OnPluginStart() {
	PrecacheSound("Passtime.BallIntercepted");
	
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre);
	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Post);
	
	soapPercent = CreateConVar("sm_soapbalancer_percent", "35", "If one team has x percent less frags than the other team, balance the teams", _, true, 0.0, true, 100.0);
	soapEnabled = CreateConVar("sm_soapbalancer_enabled", "1", "Enables/Disables the soap balancer plugin");
	soapInterval = CreateConVar("sm_soapbalancer_interval", "120", "Check every x seconds if the teams are unbalanced", _, true, 5.0);
	soapInterval.AddChangeHook(OnConVarChange);
	
	char cvarValue[16];  
	soapInterval.GetString(cvarValue, sizeof(cvarValue));
	HeartBeat = CreateTimer(StringToFloat(cvarValue), Timer_HeartBeat, _, TIMER_REPEAT);
}


public void OnClientDisconnect(int client) {
	playerArray[client][0] = 0;
	playerArray[client][1] = 0;
	ResetHeartBeat();
}

public void OnClientPostAdminCheck(int client) {
	playerArray[client][0] = 0;
	playerArray[client][1] = 0;
}


public Action Timer_HeartBeat(Handle timer) {
	if (skipHeartBeat) { 
		skipHeartBeat = false;
		return Plugin_Handled;
	}
	if (!soapEnabled.BoolValue) return Plugin_Handled;
	
	int redFrags, bluFrags, currentPlayers;

	//Loop through each player, and add the frags since the last interval to the teams total
	for (int i = 1; i < MaxClients + 1; i++) {
		if (!IsValidClient(i)) continue;
		
		if (TF2_GetClientTeam(i) == TFTeam_Spectator) {
			if (playerArray[i][3] == 0) continue;
	
			if (playerArray[i][4] == 2) {
				redFrags += (GetClientFrags(i)) - (playerArray[i][1]);
				currentPlayers++;
			}

			else if (playerArray[i][4] == 3) {
				bluFrags += (GetClientFrags(i)) - (playerArray[i][1]);
				currentPlayers++;
			}
		}
		
		if (TF2_GetClientTeam(i) == TFTeam_Red)  {
			redFrags += (GetClientFrags(i)) - (playerArray[i][1]);
			currentPlayers++;
		}

		else if (TF2_GetClientTeam(i) == TFTeam_Blue) { 
			bluFrags += (GetClientFrags(i)) - (playerArray[i][1]);
			currentPlayers++;
		}
		playerArray[i][1] = GetClientFrags(i);
		
	}
	PrintToChatAll("\x0700ffff[SB] \x07C43F3B Red Frags: %d \x074EA6C1 Blue Frags: %d", redFrags, bluFrags);

	char cvarValue[16];
	soapPercent.GetString(cvarValue, sizeof(cvarValue));
	float swapPercent = (StringToFloat(cvarValue) / 100) - 0.001;
	float p1 = float(redFrags) / float(bluFrags);
	float p2 = float(bluFrags) / float(redFrags);

	//Decide which team is dominating according to the Swap Percent value, then call the BalanceTeams funtion accordingly
	if (p1 != p2 && (currentPlayers % 2) == 0) {

		if (p1 > p2 && (1.0 - p2) > swapPercent) {
			PrintToChatAll("\x0700ffff[SB]\x07C43F3B Red team is dominating!");
			BalanceTeams(TFTeam_Red, TFTeam_Blue);
		}

		else if ( p2 > p1 && (1.0 - p1) > swapPercent) {
			PrintToChatAll("\x0700ffff[SB]\x074EA6C1 Blue team is dominating!");
			BalanceTeams(TFTeam_Blue, TFTeam_Red);
		}

		else PrintToChatAll("\x0700ffff[SB]\x073BC43B Teams are balanced!");

		
	}
	else if ((currentPlayers % 2) == 0) PrintToChatAll("\x0700ffff[SB]\x073BC43B Teams are balanced!");

	else PrintToChatAll("\x0700ffff[SB]\x01 Odd number of players, not balancing!");

	for (int i = 1; i < MaxClients + 1; i++) {
		if (!IsValidClient(i)) continue;
		playerArray[i][2] = playerArray[i][0];
	}

	return Plugin_Handled;
}

public void BalanceTeams(TFTeam largerTeam, TFTeam smallerTeam) {
	int[][] largerTeamArray = new int[MaxClients+1][2]; 
	int[][] smallerTeamArray = new int[MaxClients+1][2];	
	int largerIndex = 0, smallerIndex = 0, largerTeamDamage, smallerTeamDamage; 

	//Construct team array, containing each players damage and client index
	//This array is used in the next loop
	for (int i = 1; i < MaxClients + 1; i++) {
		if (!IsValidClient(i)) continue;
		int damage;

		if (TF2_GetClientTeam(i) == largerTeam || playerArray[i][4] == view_as<int>(largerTeam)) {
			damage = (playerArray[i][0] - playerArray[i][2]);
			largerTeamDamage += damage;
			largerTeamArray[largerIndex][0] = damage;
			largerTeamArray[largerIndex][1] = i;
			largerIndex += 1
		}

		else if (TF2_GetClientTeam(i) == smallerTeam || playerArray[i][4] == view_as<int>(smallerTeam)) {
			damage = (playerArray[i][0] - playerArray[i][2]);
			smallerTeamDamage += damage;
			smallerTeamArray[smallerIndex][0] = damage;
			smallerTeamArray[smallerIndex][1] = i;
			smallerIndex += 1;
		}
	}

	 
	int maxDifference = abs(largerTeamDamage - smallerTeamDamage);
	int idealDifference = maxDifference / 2;
	int swapArray[3];

	//Search through every player swap combination, and store the one with the value closest to swap
	for (int l = 0; l < largerIndex; l++) {
		for (int s = 0; s < smallerIndex; s++) {

			int swapDifference = largerTeamArray[l][0] - smallerTeamArray[s][0];

			if (swapDifference < maxDifference && swapDifference > 0) {
				int idealSwapDifference = abs(swapDifference - idealDifference);

				if (idealSwapDifference <= swapArray[0] || swapArray[1] == 0) {

					if (TF2_GetPlayerClass(largerTeamArray[l][1]) == TF2_GetPlayerClass(smallerTeamArray[s][1])) {
						swapArray[0] = idealSwapDifference, swapArray[1] = largerTeamArray[l][1], swapArray[2] = smallerTeamArray[s][1];
					}
				}
			}
		}
	}	
	if (swapArray[1] != 0) {

		if (TF2_GetPlayerClass(swapArray[1]) == TF2_GetPlayerClass(swapArray[2])) {

			char largerName[64], smallerName[64];
			GetClientName(swapArray[1], largerName, sizeof(largerName));
			GetClientName(swapArray[2], smallerName, sizeof(smallerName));
			PrintToChatAll("\x0700ffff[SB]\x01 Swapping player \x0700ffff%s\x01 for \x0700ffff%s", largerName, smallerName);
			SetHudTextParams(-1.0, 0.22, 3.0, 240, 0, 240, 255);	
			ShowHudText(swapArray[1], -1, "You are being autobalanced in 3 seconds");
			ShowHudText(swapArray[2], -1, "You are being autobalanced in 3 seconds");
			ClientCommand(swapArray[1], "playgamesound Passtime.BallIntercepted");
			ClientCommand(swapArray[2], "playgamesound Passtime.BallIntercepted");

			PlayerSwap playerSwap;
			playerSwap.largerTeam = largerTeam;
			playerSwap.largerPlayer = swapArray[1];
			playerSwap.largerClass = TF2_GetPlayerClass(swapArray[1]);
			playerSwap.smallerTeam = smallerTeam;
			playerSwap.smallerPlayer = swapArray[2]
			playerSwap.smallerClass = TF2_GetPlayerClass(swapArray[2]);
			ArrayList playerSwapContainer = new ArrayList(sizeof(PlayerSwap));
			playerSwapContainer.PushArray(playerSwap)
			CreateTimer(3.0, SwapTeams, playerSwapContainer); 
		}
	}
	else PrintToChatAll("\x0700ffff[SB] \x01Could not find a suitable player swap");
		
}

public Action Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	int oldTeam = event.GetInt("oldTeam");

	//This is an anticheat method used to prevent people from joining spectator and back to delay the heart beat
	if (event.GetInt("team") == 1) {	
		if (oldTeam == 2 || oldTeam == 3) playerArray[client][3] = 1, playerArray[client][4] = oldTeam;
	}

	else if (oldTeam == 1 || oldTeam == 0) {
		if (playerArray[client][3] == 1) playerArray[client][3] = 0, playerArray[client][4] = 0;
		else ResetHeartBeat();
	}
}

public Action Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast) {
	int damage = event.GetInt("damageamount");
	int playerHealth = GetClientHealth(GetClientOfUserId(event.GetInt("userid")));
	int userid = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int trueDamage = damage;

	//If the player takes overkill damage, playerHealth will be a negative value of the amount of overkill. 
	//This is used to get the actual amount of damage dealt, not including overkill.
	if (playerHealth < 0) { 
		trueDamage = trueDamage + playerHealth;
	}

	if (IsValidClient(attacker) && userid != attacker) {
		playerArray[attacker][0] += trueDamage;
	} 

	return Plugin_Continue;
}


public void OnConVarChange(ConVar convar, char[] oldValue, char[] newValue) {
	float interval = StringToFloat(newValue);
	if (interval < 5) {
		PrintToServer("[SoapBalancer] Invalid sm_soapbalancer_interval value! Please use a value greater or equal to 5 seconds!")
	}

	else {
		KillTimer(HeartBeat, false);
		HeartBeat = CreateTimer(interval, Timer_HeartBeat, _, TIMER_REPEAT)
	}
}


public Action SwapTeams(Handle timer, ArrayList playerSwapContainer) {
	PlayerSwap swap;
	playerSwapContainer.GetArray(0, swap);

	if (IsValidClient(swap.largerPlayer) && IsValidClient(swap.smallerPlayer)) {
		TF2_ChangeClientTeam(swap.largerPlayer, swap.smallerTeam);
		TF2_ChangeClientTeam(swap.smallerPlayer, swap.largerTeam);
		TF2_SetPlayerClass(swap.largerPlayer, swap.largerClass);
		TF2_SetPlayerClass(swap.smallerPlayer, swap.smallerClass);
	}

	else {
		PrintToChatAll("\x0700ffff[SB]\x01 A player left before getting swapped");
	}
	return Plugin_Handled;
}

//This Function simply resets the heart beat interval, and starts counting the players frags and damage from 0 again.
public void ResetHeartBeat() {
	for (int i = 0; i < MaxClients + 1; i++) {
		if (!IsValidClient(i)) continue;
		playerArray[i][1] = GetClientFrags(i);
		playerArray[i][2] = playerArray[i][0];
	}

	skipHeartBeat = true;
	TriggerTimer(HeartBeat, true);
}
//THExeon snippet
public bool IsValidClient(int client) {
	if (client > 4096) client = EntRefToEntIndex(client);
	if (client < 1 || client > MaxClients) return false;
	if (!IsClientInGame(client)) return false;
	//if (IsFakeClient(client)) return false;
	if (GetEntProp(client, Prop_Send, "m_bIsCoaching")) return false;
	return true;
}

public int abs(x) {
   return x>0 ? x : -x;
}
