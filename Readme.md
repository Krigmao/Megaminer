This Megaminer fork is aimed at AMD + CPU usage without interfering with normal PC usage.

AMD miners tuned for RX480/580 with low memory timings

Recommended drivers for AMD are latest Adrenalin edition or Radeon Blockchain beta from August 23 for specific cases
	- MkxMiner ASM mode works only with Blockchain drivers
	- CastXMR gives higher hashrate with Blockshain drivers
	- AMD monitoring with OverdriveN is unsupported on Blockchain driver and adli is used in that case with less info

New features from tutulino are merged manually after a review to ensure stability.

NVidia miners are untested.


## Changes from tutulino's branch

* Support SSL Mining on supported pools (MiningPoolHub, NiceHash, some coins on Suprnova)
* Additional miners
	- EthMiner (AMD, NVidia)
	- lolMiner-Mnx (AMD, NVidia)
	- MkxMiner (AMD)
	- NHeqminer (CPU)
	- NsCudaMiner (NVidia)
	- OptiminerZcash (AMD)
	- OptiminerZero (AMD, NVidia)
	- Phoenix (AMD, NVidia)
	- SgminerAllium (AMD)
	- SgminerC11 (AMD)
	- SgminerKeccakC (AMD)
	- XMR-Stak (AMD, NVidia, CPU)
	- XMRig (AMD, NVidia, CPU)
	- XmrMiner (AMD)
* Miner optimizations for CPU and AMD
* Low process priority for cpu miners to prevent responsiveness issue
* Use C# assembly to prevent miners from stealing focus
* Poll mining api to display projected profits for Manual mining
* Support reporting mining stats to multipoolminer.io/monitor
* Allow mining specific Algo instead of coin in Manual mode
* Profit display in mBTC instead of BTC with too many zeroes
* Support profitability info for additional coins from WhatToMine pool (added by tutulino now)
* Power usage aproximation for AMD and CPU
	- You will need to add TDP values for your hardware in _cpu-tdp.json_ or _amd-cards-tdp.json_ if they are not there
* Support any fiat currency which is supported by CoinDesk for profit display
* Allow dual mining any Ethash coin instead of ETH/ETC only
* Filter out algos without solved blocks in 24h on MPH and YIIMP type pools
* Filter out non-paying algos on NiceHash
* Allow decimal values in hashrate from algos with very low hashrate (i.e. EquihashZero)
* Faster wallet display
* Support SHA256 validation for miner downloads
* Fix algo divisors on YIIMP type pools
* Additional pools
	- AntMinePool
	- Bilbotel.fr
	- BlockMunch
	- FairPool
	- Mining Dutch
	- Protopool
	- Suprnova (up to date algos)
	- Zergpool
* Various small fixes, code optimizations and formatting changes

### Donations are welcome
- BTC - 3FzmW9JMhgmRwipKkNnphxG73VPQMsYsN6
- ETH - 0x38973025136D1a5B773aE71c02cA24b365850A9A
- LTC - MM8RmXUgxDwHJxrC54muF7KHciSCFS3gx3


Original author's wallets listed at the end of original readme below



### Original readme file below


---- POOLS SUPORTED ---------------------------------------

AHASHPOOL -- Anonymous, autoexchange to selected coin in config.txt
ALTMINER -- Anonymous, no autoexchange, must set a wallet for each coin
BLAZEPOOL -- Anonymous, autoexchange to selected coin in config.txt
BLOCKSFACTORY -- Registration required, one registration for all pools, no autoexchange
FLYPOOL -- Anonymous, manual mode only
HASHREFINERY -- Anonymous, autoexchange to selected coin in config.txt
ITALYIIMP -- Anonymous, autoexchange to selected coin in config.txt
MININGPOOLHUB -- registration required, autoexchange to selected coin on pool´s web.
NANOPOOL -- Anonymous, no autoexchange, must set a wallet for each coin
NICEHASH-- Anonymous, autoexchange to BTC
SUPRNOVA -- Registration required, one registration for all pools except bitcoin cash, no autoexchange
UNIMINING -- No registration, No autoexchange, need wallet for each coin on config.txt
WHATTOMINE (virtual) - Based on statistics of whattomine, it use MPH and Suprnova servers to mine most profitable coin, you must configure wallets on config.cfg and also have an account on Suprnova to us
YIIMP -- Anonymous, no autoexchange, must set a wallet for each coin
ZERGPOOL -- Anonymous, autoexchange to selected coin in config.txt
ZPOOL -- Anonymous, autoexchange to selected coin in config.txt


---- INSTRUCTIONS ----------------------------------------------

0. Download source code from latest Release from github (you dont need executable file)

1. Edit CONFIG.TXT file before mining

2. Exec start.bat for manual selection or edit AutoStartExample.bat for automatic boot without user prompt, you can use this parameters on your batch
    - PoolsName = separated comma string of pools to run
	- MiningMode = Mode to check profit, note not all pools suport all modes (Automatic/Automatic24h/Manual). If manual mode is selected one coin must be passed on Coinsname parameter
	- Algorithm = separated comma string of algorithms to run (optional)
    - CoinsName = separated comma string of Coins to run (optional)
    - Groupnames = Groups of gpu/cpu to run (based on your defined groups in config.txt @@Gpugroups section) (optional)
	- PercentToSwitch = Overrides config.txt config, percent to switch miner/algo, new miner/algo only will be launched if new profit is greater than actual profit in specified percent (optional)


3. Firt time, software will be donwloaded from miners github repositories
	- As usual, some miners are detected as virus by your Antivirus, to avoid this you must set your instalation directory as excluded. For Windows Defender MM path is excluded automatic

4. Your system will be benchmarked (long process)

5. Make profit
	- Except Nicehash (where you sell your power to indicated price), pools always overstimated profit, you must understand profit column as a way to get best algoritmh. Your real profit will be lower.

6. Tuning (optional)
	- you can edit miners folders content to delete miners or to assign/unassign algos to miners.
	- you can edit pools folders content to delete pools
	- for advanced users, you can create miners or pools if are based on existing one.



---- UPGRADE PROCEDURE ------------------------------------

Safest way is download new software and copy from old version "stats" folders and "config.txt" file.
If new verson has no miners update you can copy "bin" folder
If there is a new miner version is recomended delete miner_algo_hashrate.txt files on miners folder to force benchmark again.


-------NEW FEATURES OVER BASE SOFTWARE -----------

-Menus sytem to choose coin/algo/pool and start mining

-One file config to start mining

-Can mine on "Virtual" Pool Whattomine, based on statistics of whattomine, it use MPH,Yiimp and Suprnova servers to mine most profitable coin, you must configure wallets on config.cfg and also have an account on Suprnova to use.

-Can mine on any of this pools (or all at same time): Ahashpool, Nanopool, YIIMP, Nicehash, Zpool, Unimining, Whattomine (virtual) HashRefinery, MPH with auto coin change based on pool profit for each algorithm with dual mining between diferent pools (ex. Eth on MPH and lbry on Zpool)

-Can mine on Suprnova,Nicehash, MPH, Flypool or BlocksFactory pool without autochange or profit calculation, manual coin selection

-Fastest miner for each algo/coin preselected for Nvidia Pascal (08/01/2017) on all pools.

-Dual Mining between different pools (ex. Eth on MPH and lbry on Zpool)

-Profit info from Whattomine,Bittrex and Cryptopia (based on your real hashrate) for manual coin selection

-Unified software repository for all pools, no need one program for each pool

-On fail no wait for interval ends, instant relaunch.

-Auto Interval time for benchmarks, no need to change interval more.

-Local currency info on main screen

-Lastest version of miners available

-GPU Info (AMD/Nvidia) (Power, fan, temperatures, eficency...)

-Pools Wallets actual and evolution info

-Option to autochange based on 24h statistics (on supported pools)

-Option for asociate command to launch before run to each miner (nvidia inspector for example to set overclock)

-Miners and Pools fees are included in profit calculation

-For mixed rigs (or for testing purpose on same cards rigs) you can group your cards allowing each group work at its best algo and difficulty

-Option to switch miner only if profit is a percent upper than actual (defined by you)

-Automatic NVIDIA Gpu Power limit, you can define any power limit values (90%, 80%, etc) for each winner miner/algo MM checks what of that power limit point is more profitable at each interval based in power cost, hashrate and reward.

-Delayed miners closing, while new miner is starting, old one continue mining

----- DISCLAIMER ---- ------------------------------------------

Tested on nvidia pascal 10X0 and AMD RX580

Only for Windows

Core for auto change pools is forked from AaronSace MultipoolMiner, you can read info at https://github.com/aaronsace/MultiPoolMiner

Profit calculations are estimates based on info provided by Pools/Whattomine for your bechmarked hashrate extrapolated to 24h. No real profit warranty except nicehash, where you are selling your power at indicated price.

Pools or Whattomine statistics are based on past (luck, difficulty, exchange-rate, pool hashrte, network hashrate, etc), it can be not very accurate, usually expected profit is near 50% pool indicates.

Local Currency exchange rate to BTC is taken from Coindesk, Local currency profit can vary from whattomine revenue (instant), BTC revenue must be exact.


Based 50% on aaronsace, 50% is mine (aprox.) Donations to

BTC: 1AVMHnFgc6SW33cwqrDyy2Fug9CsS8u6TM
LTC: LVwuYbAvbMDVapheQBA7o2qQ2mKTEXVDbX
BCH: 1N7wsg4JmWJLP6BuHUP5rwsAXnQjTWPBjr
ETH: 0x9b7A01Bf5bD29c66d228d372B5bD1C43cDb78AcC




---- NO SCAM WARRANTY --------------------------------------------

You can see .ps1 files, are source code, miners are downloaded from github


