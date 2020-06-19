# soapbalancer
TF2 balancing plugin intended for SOAP DM servers
## Cvars

sm_soapbalancer_enabled 1/0, default 1, Enables/Disables the plugin

sm_soapbalancer_interval #seconds, default 120, Interval between each team balance

sm_soapbalancer_percent #percent, default 35, Percentage that the plugin considers "unbalanced"

## Description

  Installation: Download and move the soapbalancer.smx plugins into your servers tf/addons/sourcemod/plugins directory.

  More detailed plugin description: https://pastebin.com/Gt8Zdxkw

  An explanation of the logic used to decide the best possible swap between 2 players

  In the example below, the numbers would be replaced with actual damage values.
  ![Swap logic](https://cdn.discordapp.com/attachments/509506719236358144/722336000881328128/unknown.png)
