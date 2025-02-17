# Changelog

## [v0.5.0](https://github.com/PathOfBuildingCommunity/PathOfBuilding/tree/v0.5.0) (2025/02/12)

[Full Changelog](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/compare/v0.4.1...v0.5.0)

## What's Changed
### New to Path of Building
- Add Support for Ailment chance calculations [\#628](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/628) ([LocalIdentity](https://github.com/LocalIdentity), [OrderedSet86](https://github.com/OrderedSet86))
- Scale base Shock calculation by shock effect mods on tree and gear [\#628](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/628) ([LocalIdentity](https://github.com/LocalIdentity))
- Use count to set number of active Minions for Reservation calculations [\#761](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/761) ([mauriliogenovese](https://github.com/mauriliogenovese))
- Add support for Armour Break [\#731](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/731) ([majochem](https://github.com/majochem))
- Add support for Blasphemy reserving Spirit [\#736](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/736) ([Paliak](https://github.com/Paliak))
- Add support for Vulnerability" ignore x Armour" mod [\#733](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/733) ([majochem](https://github.com/majochem))
- Add support for War Banner and Defiance Banner [\#752](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/752), [\#753](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/753) ([Blitz54](https://github.com/Blitz54))
- Add support for Rolling Slam "more damage against heavy stunned enemies" [\#750](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/750) ([Blitz54](https://github.com/Blitz54))
- Add support for Acolyte of Chayula Darkness Ascendancy [\#715](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/715) ([MrHB212](https://github.com/MrHB212))
- Add support for "I Am The Thunder..." and "I Am The Blizzard..." [\#768](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/768) ([madxmike](https://github.com/madxmike))
- Add support for Pinned recently [\#723](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/723) ([Blitz54](https://github.com/Blitz54))
- Add Support for extra Exposure [\#720](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/720) ([MrHB212](https://github.com/MrHB212))
- Add parsing for "Your speed is unaffected by Slows" [\#700](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/700) ([RealWhimsy](https://github.com/RealWhimsy))
- Add Support for "Slam skills have +% increased Area of Effect" [\#705](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/705) ([MrHB212](https://github.com/MrHB212))
- Add support for "against enemies within/further than" [\#734](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/734) ([Blitz54](https://github.com/Blitz54))
- Add support for ignore Warcry Cooldown [\#741](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/741) ([MrHB212](https://github.com/MrHB212))
- Add support for "Electrocution" tree mods [\#758](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/758), [\#757](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/757) ([Blitz54](https://github.com/Blitz54))
- Add support for Break Armour on Critical Hit with Spells [\#755](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/755) ([majochem](https://github.com/majochem))
- Add support for Gamblesprint movement speed [\#728](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/728) ([Blitz54](https://github.com/Blitz54))
- Add support for Dustbloom Life regen [\#727](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/727) ([Blitz54](https://github.com/Blitz54))
- Add support for Vile Knight enemy in presence Duration mod [\#706](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/706) ([Blitz54](https://github.com/Blitz54))
### Fixed Crashes
- Fix crash from importing item with Mana leech mods [\#735](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/735) ([nessgor](https://github.com/nessgor))
### User Interface
- Fix the highlight node circle being too small [\#729](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/729) ([LocalIdentity](https://github.com/LocalIdentity))
### Fixed Calculations
- Incorrect rounding for Reservation calculations [\#725](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/725) ([nessgor](https://github.com/nessgor))
- Fix calculation of Leech passive nodes [\#708](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/708) ([MrHB212](https://github.com/MrHB212))
- Fix comparison tooltips for builds with Time-Lost Jewels [\#709](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/709) ([Peechey](https://github.com/Peechey))
### Fixed Behaviours
- Fix "Critical strike in last 8 seconds" mods always applying instead of using a config [\#711](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/711) ([MrHB212](https://github.com/MrHB212))
### Accuracy Improvements
- Update Time-Lost Jewel affixes with proper wording [\#767](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/767) ([Peechey](https://github.com/Peechey))
- Fix duplicate skill for Greater Lightning Bolt and Decompose [\#763](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/763) ([mauriliogenovese](https://github.com/mauriliogenovese))


## [v0.4.1](https://github.com/PathOfBuildingCommunity/PathOfBuilding/tree/v0.4.1) (2025/02/04)

[Full Changelog](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/compare/v0.4.0...v0.4.1)

## What's Changed
### Fixed Crashes
- Fix crash due to missing DLL ([Wires77](https://github.com/Wires77))


## [v0.4.0](https://github.com/PathOfBuildingCommunity/PathOfBuilding/tree/v0.4.0) (2025/02/04)

[Full Changelog](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/compare/v0.3.0...v0.4.0)

## What's Changed
### New to Path of Building
- Add limited support for Unicode file paths [\#372](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/372) ([zao](https://github.com/zao))
- Add Shift + Ctrl + V hotkey to bypass item import confirmation box [\#624](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/624) ([LocalIdentity](https://github.com/LocalIdentity))
#### Skills
- Add support for Detonate Dead Corpse explosion calculation [\#541](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/541) ([g1y5x3](https://github.com/g1y5x3))
- Add Greater Lightning Bolt [\#549](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/549) ([etojuice](https://github.com/etojuice))
- Add Lightning Conduit Shock Mod [\#497](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/497) ([Saeldur](https://github.com/Saeldur))
- Add support for Skeletal Storm Mage "Life as extra ES" mod [\#655](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/655) ([Blitz54](https://github.com/Blitz54))
- Add support for Total Cast Time on Comet and Lightning Conduit [\#685](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/685) ([Peechey](https://github.com/Peechey))
- Add support for Empowering buff effects [\#563](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/563) ([TPlant](https://github.com/PJacek))
- Add support for Charge Infusion Support [\#528](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/528) ([xspirus](https://github.com/xspirus))
- Add support for Inevitable Critical Support [\#603](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/603) ([jjbi123](https://github.com/jjbi123))
- Add support for Overabundance limit mod [\#608](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/608) ([Nostrademous](https://github.com/Nostrademous))
#### Items
- Add support for Attacks Gain Extra mods on Quivers [\#666](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/666) ([Blitz54](https://github.com/Blitz54))
- Add support Spell Mana cost converted to Life cost Dagger Implicit [\#670](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/670) ([Blitz54](https://github.com/Blitz54))
#### Uniques
- Add support for Mahuxotl's Machination [\#521](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/521) ([etojuice](https://github.com/etojuice))
- Add support for several mods in Uniques [\#554](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/554) ([Blitz54](https://github.com/Blitz54))
- Add support for Threaded Light Woven Focus Spirit unique mod [\#595](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/595) ([PGDeve](https://github.com/PGDeve))
- Add support for Windscream's Curse delay mod [\#577](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/577) ([Blitz54](https://github.com/Blitz54))
- Add support for Svalinn's lucky block mod [\#669](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/669) ([Blitz54](https://github.com/Blitz54))
- Add support for Trephina Crit mod [\#668](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/668) ([Blitz54](https://github.com/Blitz54))
- Add support for Skin of the Loyal over-cap mods [\#672](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/672) ([Blitz54](https://github.com/Blitz54))
- Add support for Burden of Shadows' 1% inc Chaos damage per 3 Life cost [\#692](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/692) ([Blitz54](https://github.com/Blitz54))
- Add support for Infinite Pursuit Movement Speed mod [\#678](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/678) ([Blitz54](https://github.com/Blitz54))
- Add support for Carrion Call Minions Resist mod [\#679](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/679) ([Blitz54](https://github.com/Blitz54))
#### Ascendancy
- Add support for Stormweaver's "Scouring Winds" node [\#495](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/495) ([Saeldur](https://github.com/Saeldur))
- Add support for Chronomancer's "Quicksand Hourglass" node [\#683](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/683) ([igorwessel](https://github.com/igorwessel))
- Add support for Chronomancer's "Now and Again" node [\#604](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/604) ([igorwessel](https://github.com/igorwessel))
- Add support for Invoker's  "Sunder my Enemies..." node [\#625](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/625) ([Jonathan-Dang](https://github.com/Jonathan-Dang))
- Add support for Invokers "and protect me from Harm" node [\#512](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/512) ([nbrugger-tgm](https://github.com/nbrugger-tgm))
#### Keystone
- Add support for Iron Will and Iron Grip [\#675](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/675) ([Blitz54](https://github.com/Blitz54))
- Add support for Heroic Tragedy Timeless Jewel Keystones [\#689](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/621, https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/689) ([Peechey, @justjuangui](https://github.com/Peechey, @justjuangui))
- Add Support for Necromantic Talisman [\#645](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/645) ([majochem](https://github.com/majochem))
- Add support for Dance with Death and Charm mods [\#636](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/636) ([Blitz54](https://github.com/Blitz54))
- Add support for Glancing Blows and Stand Ground [\#631](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/631) ([Blitz54](https://github.com/Blitz54))
- Add support for Oasis keystone [\#513](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/513) ([etojuice](https://github.com/etojuice))
#### Tree
- Add support for several mods on Tree nodes [\#635](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/554, https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/635) ([Blitz54](https://github.com/Blitz54))
- Add support for nearby Allies mods [\#492](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/492) ([ltogniolli](https://github.com/ltogniolli))
- Add support for Grenade Damage, Area and Cooldown mods [\#490](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/490) ([ltogniolli](https://github.com/ltogniolli))
- Add support for Curse AoE on the Tree [\#577](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/577) ([Blitz54](https://github.com/Blitz54))
- Add support for Offering skills' AoE and Duration mods [\#598](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/598) ([Blitz54](https://github.com/Blitz54))
- Add support for Critical Damage Bonus per Power Charge [\#641](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/641) ([etojuice](https://github.com/etojuice))
- Add Times Stunned Recently and edited Warcries used Recently [\#637](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/637) ([Blitz54](https://github.com/Blitz54))
- Add support for Minions "Life as extra ES" mod [\#655](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/655) ([Blitz54](https://github.com/Blitz54))
- Add support for Stars Aligned node [\#656](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/656) ([Blitz54](https://github.com/Blitz54))
- Add support for Reduced Bleeding Duration on you [\#667](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/667) ([Blitz54](https://github.com/Blitz54))
- Add support for Attack Speed when on full mana [\#676](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/676) ([Blitz54](https://github.com/Blitz54))
- Add support for Regenerative Flesh notable [\#681](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/681) ([Blitz54](https://github.com/Blitz54))
- Add support for Heavy Armour notable [\#687](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/687) ([dance](https://github.com/dance))
- Add support for "ignore (non-negative) elemental resistances" mods [\#690](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/690) ([majochem](https://github.com/majochem))
### Fixed Crashes
- Fix crash when switching between multiple choice Ascendancies [\#597](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/597) ([submitteddenied](https://github.com/submitteddenied))
- Fix item range crash on Ventor's Gamble [\#630](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/630) ([QuickStick123](https://github.com/QuickStick123))
### User Interface
- Add tooltip to clarify distance to enemy units [\#553](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/553) ([jjbi123](https://github.com/jjbi123))
- Fix some mods not scaling correctly with Hulking Form [\#580](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/580) ([Peechey](https://github.com/Peechey))
- Fix numbers not showing to correct decimal places in some UI mod lines [\#551](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/551) ([QuickStick123](https://github.com/QuickStick123))
- Update "Dmg. per ailment" title and ailment DPS breakdown titles [\#569](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/569) ([pauloday](https://github.com/pauloday))
- Make stack potential more understandable [\#609](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/609) ([pauloday](https://github.com/pauloday))
- Hide stat comparisons for hovered gem quality if gem has no quality stats [\#653](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/653) ([etojuice](https://github.com/etojuice))
- Widen dropdown to properly display ascendancy class names [\#680](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/680) ([MrHB212](https://github.com/MrHB212))
- Fix width of GitHub link button [\#596](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/596) ([submitteddenied](https://github.com/submitteddenied))
### Fixed Calculations
- Fix many gems not showing the correct stats on some parts [\#661](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/661) ([LocalIdentity](https://github.com/LocalIdentity))
- Fix Corrupting Cry using Reduced area instead of Less [\#533](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/533) ([Wires77](https://github.com/Wires77))
- Fix Corrupted Unique roll ranges formula [\#581](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/581) ([Peechey](https://github.com/Peechey))
- Fix total Flask charges gained in Flask uptime calculation [\#639](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/639) ([etojuice](https://github.com/etojuice))
- Fix Palm skills not scaling with unarmed damage [\#665](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/665) ([LocalIdentity](https://github.com/LocalIdentity))
- Fix Magma Barrier damage calculation [\#664](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/664) ([LocalIdentity](https://github.com/LocalIdentity))
- Fix Voltaic Nova and Freezing Nova damage scaling [\#663](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/663) ([LocalIdentity](https://github.com/LocalIdentity))
- Fix Herald of Thunder not using weapon damage [\#662](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/662) ([LocalIdentity](https://github.com/LocalIdentity))
### Fixed Behaviours
- Fix Concoction skills not being treated as Unarmed [\#659](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/659) ([Peechey](https://github.com/Peechey))
- Fix Ice Bite applying when the enemy wasn't Frozen [\#508](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/508) ([xspirus](https://github.com/xspirus))
- Fix Frost Bomb not applying Cold Exposure [\#511](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/511) ([etojuice](https://github.com/etojuice))
- Fix performance issues with Time-Lost Jewels [\#555](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/555) ([Peechey](https://github.com/Peechey))
- Fix Support gems counting towards limit when not enabled [\#612](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/612) ([ismyilson](https://github.com/ismyilson))
- Fix "from Equipped Shield" and add support for "from Equipped Focus" [\#629](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/629) ([Peechey](https://github.com/Peechey))
- Fix missing trade tags on certain items resulting in them not being generated [\#627](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/627) ([QuickStick123](https://github.com/QuickStick123))
- Fix Charge Infusion not working sometimes [\#654](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/654) ([LocalIdentity](https://github.com/LocalIdentity))
### Accuracy Improvements
- Fix parsing for Shadow Dancing [\#560](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/560) ([Blitz54](https://github.com/Blitz54))
- Fix Gamblesprint's missing movement speed mod [\#536](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/536) ([PGDeve](https://github.com/PGDeve))
- Fix Attack Damage mod missing from Ruby Jewel [\#578](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/578) ([sida-wang](https://github.com/sida-wang))
- Improve EHP accuracy when using MoM and Eldritch Battery [\#552](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/552) ([Edvinas-Smita](https://github.com/Edvinas-Smita))


## [v0.3.0](https://github.com/PathOfBuildingCommunity/PathOfBuilding/tree/v0.3.0) (2025/02/04)

[Full Changelog](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/compare/v0.2.0...v0.3.0)

## What's Changed
### New to Path of Building
- Add Emotion filtering to Anoint popup [\#435](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/435) ([Quxxy](https://github.com/Quxxy))
- Add support for Sceptre 'Allies in your presence' mods [\#481](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/481) ([LocalIdentity](https://github.com/LocalIdentity))
- Add the ability to custom change max node depth for heat map [\#446](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/446) ([DoubtinGiyov](https://github.com/DoubtinGiyov))
- Add support for Buff Expiry Rate [\#455](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/455) ([igorwessel](https://github.com/igorwessel))
- Add support for Critical Weakness debuff [\#456](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/456) ([Edvinas-Smita](https://github.com/Edvinas-Smita))
- Add support for merging mods on nodes in radius of Time-Lost jewels [\#474](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/474) ([Peechey](https://github.com/Peechey))
- Add support for increased Effect of Small Passive Skills in Radius for Time-Lost Jewels [\#443](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/443) ([Peechey](https://github.com/Peechey))
- Add support for Armour Buff on Scavenged Plating [\#484](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/484) ([LocalIdentity](https://github.com/LocalIdentity))
- Add support for Controlled Destruction [\#405](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/405) ([TPlant](https://github.com/PJacek))
- Add support for Charge consumed recently tree nodes [\#400](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/400) ([trompetin17](https://github.com/justjuangui))
- Add support for Monk's Reality Rending node [\#398](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/398) ([Nostrademous](https://github.com/Nostrademous))
- Add support for Monk's Into the Breach and Lucid Dreaming Ascendancies [\#436](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/436) ([Nostrademous](https://github.com/Nostrademous))
- Add support for Unnatural Resilience notable [\#377](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/377) ([Peechey](https://github.com/Peechey))
- Add support for Harness the Elements notable and Electrocute to config tab [\#411](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/411) ([lrzp](https://github.com/lrzp))
- Add support for a bunch of tree mods [\#422](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/422) ([ltogniolli](https://github.com/ltogniolli))
- Add support for Grinning Immolation and Pain Attunement [\#463](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/463) ([etojuice](https://github.com/etojuice))
- Add support for 'You have no Elemental Resistances' modifier [\#453](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/453) ([etojuice](https://github.com/etojuice))
- Add support for Mask of The Stitched Demon [\#459](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/459) ([etojuice](https://github.com/etojuice))
* Add support for Kaom's Heart by (@etojuice, @ltogniolli) in https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/468, https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/475
### Fixed Crashes
- Fix crash when hovering over breakdown for Minion skills [\#480](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/480) ([TPlant](https://github.com/PJacek))
### Fixed Calculations
- Fix +Levels to Gems on Quivers not working sometimes [\#389](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/389) ([hugocornago](https://github.com/hugocornago))
- Fix Minion Spell skills doing 0 damage [\#482](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/482) ([LocalIdentity](https://github.com/LocalIdentity))
- Fix Archmage Mana cost [\#399](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/399) ([TPlant](https://github.com/PJacek))
- Fix Scattershot Attack/Cast speed value [\#395](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/395) ([deathbeam](https://github.com/deathbeam))
- Fix Penetration calculations [\#390](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/390) ([TPlant](https://github.com/PJacek))
- Fix Chain Support applying to all damage instead of just hits [\#407](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/407) ([TPlant](https://github.com/PJacek))
- Fix Herald interaction with Coming Calamity [\#429](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/429) ([xspirus](https://github.com/xspirus))
- Fix Maligaro's Virtuosity Critical Damage Bonus calculation [\#467](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/467) ([etojuice](https://github.com/etojuice))
### Fixed Behaviours
- Fix Concoction skills not being treated as Unarmed [\#465](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/465) ([Peechey](https://github.com/Peechey))
- Fix Passive Nodes not showing updated value when Hulking Form is allocated [\#393](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/393) ([trompetin17](https://github.com/justjuangui))
- Fix Ingenuity Belt not working with reflected rings from Kalandra's Touch [\#418](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/418) ([etojuice](https://github.com/etojuice))
- Fix passive nodes being permanently attached to a Weapon Set [\#425](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/425) ([Peechey](https://github.com/Peechey))
- Fix projectile scaling for Bonestorm and Gas Arrow [\#476](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/476) ([Peechey](https://github.com/Peechey))
### Accuracy Improvements
- Fix value of Onslaught Movement Speed buff [\#419](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/419) ([OrderedSet86](https://github.com/OrderedSet86))


## [v0.2.0](https://github.com/PathOfBuildingCommunity/PathOfBuilding/tree/v0.2.0) (2025/02/04)

[Full Changelog](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/compare/v0.1.0...v0.2.0)

## What's Changed
### New to Path of Building
- Clicking on the skill passives display cycles through Weapon passive allocation modes [\#43](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/43) ([trompetin17](https://github.com/justjuangui))
- Add support for +Elemental Spell levels [\#21](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/21) ([deathbeam](https://github.com/deathbeam))
- Add support for Archmage [\#9](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/9) ([TPlant](https://github.com/PJacek))
- Add support for Concoction skills [\#26](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/26) ([LocalIdentity](https://github.com/LocalIdentity))
- Add support for Offering Skills [\#60](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/60) ([LocalIdentity](https://github.com/LocalIdentity))
- Add support for Feeding Frenzy [\#59](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/59) ([LocalIdentity](https://github.com/LocalIdentity))
- Add support for Cold Exposure and Lightning Exposure [\#11](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/11) ([deathbeam](https://github.com/deathbeam))
- Add support for Armour applying to Elemental Damage Taken [\#57](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/57) ([Edvinas-Smita](https://github.com/Edvinas-Smita))
- Add support for Small/Notable Passive mods on all Time-Lost Jewels [\#48](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/48) ([Peechey](https://github.com/Peechey))
- Add Support for Renly's Training Ascendancy node [\#34](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/34) ([LocalIdentity](https://github.com/LocalIdentity))
- Add support for Stormweaver's Shaper of Winter, Heavy Snows and Strike Twice nodes [\#15](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/15) ([Lexy](https://github.com/learn2draw))
- Add support for Radius mods on Time-Lost Jewels [\#33](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/33) ([etojuice](https://github.com/etojuice))
- Add support for Minions inheriting player Dexterity [\#58](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/58) ([LocalIdentity](https://github.com/LocalIdentity))
- Add Support for Blood Magic Keystone [\#35](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/35) ([hugocornago](https://github.com/hugocornago))
- Add Glimpse of Chaos [\#41](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/41) ([TPlant](https://github.com/PJacek))
- Add support for Breach Ring quality [\#47](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/47) ([Lexy](https://github.com/learn2draw))
- Add massive variant to Controlled Metamorphosis [\#8](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/8) ([deathbeam](https://github.com/deathbeam))
- Add support for 8s Recoup and new mods [\#54](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/54) ([LocalIdentity](https://github.com/LocalIdentity))
- Add support for all damage conversion (like Avatar of Fire) [\#53](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/53) ([deathbeam](https://github.com/deathbeam))
- Add support for parsing Damage gain as (without as extra) [\#56](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/56) ([deathbeam](https://github.com/deathbeam))
- Add support for importing builds from PoE2DB [\#27](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/27) ([Peechey](https://github.com/Peechey))
- Add support for importing builds from poe2.ninja [\#45](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/45) ([rasmuskl](https://github.com/rasmuskl))
### Fixed Crashes
- Fix common crash when allocating Infernal Hound or equipping Minion Skills [\#1](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/1) ([paliak](https://github.com/paliak))
- Fix crash when allocating some nodes with weapon set passives [\#7](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/7) ([trompetin17](https://github.com/justjuangui))
- Fix crash when using Deep Cuts or Deadly Poison [\#3](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/3) ([deathbeam](https://github.com/deathbeam))
- Fix crash when allocating Explosive Impact [\#13](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/13) ([Peechey](https://github.com/Peechey))
- Fix crash when searching for Skill Gems [\#17](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/17) ([deathbeam](https://github.com/deathbeam))
- Fix crash when viewing breakdown of nodes in starting Witch area [\#32](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/32) ([trompetin17](https://github.com/justjuangui))
### User Interface
- Fix Ctrl + Z & Ctrl + Y not saving the allocated attribute stats [\#6](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/6) ([Peechey](https://github.com/Peechey))
- Fix node power visuals while processing/calculating [\#25](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/25) ([trompetin17](https://github.com/justjuangui))
- Change config option to use 1 Enemy Distance value [\#36](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/36) ([deathbeam](https://github.com/deathbeam))
- Fix weapon tree hotkey overriding other tree hotkeys [\#38](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/38) ([Wires77](https://github.com/Wires77))
- Increased hover range for Skill Tree nodes [\#16](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/16) ([trompetin17](https://github.com/justjuangui))
- Remove Ward displays and update Spirit color [\#19](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/19) ([Peechey](https://github.com/Peechey))
### Fixed Calculations
- Fix some increased critical damage modifiers incorrectly applying as base critical damage modifiers [\#31](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/31) ([TPlant](https://github.com/PJacek))
- Fix Widowhail & other Quiver bonus scaling [\#40](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/40) ([Nostrademous](https://github.com/Nostrademous))
- Fix base Exposure value [\#11](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/11) ([deathbeam](https://github.com/deathbeam))
- Fix base Shock + Chill values [\#15](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/15) ([Lexy](https://github.com/learn2draw))
- Fix Searing Flame ailment magnitude [\#12](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/12) ([deathbeam](https://github.com/deathbeam))
- Fix Arrow Speed not applying to Feathered Fletching node [\#50](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/50) ([LocalIdentity](https://github.com/LocalIdentity))
- Fix Explosion damage for Frozen Locus and Shattering Palm [\#49](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/49) ([LocalIdentity](https://github.com/LocalIdentity))
- Fix calculation of Base Evasion from levels [\#51](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/51) ([LocalIdentity](https://github.com/LocalIdentity))
- Update chaos damage taken to deal double damage to Energy Shield [\#62](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/62) ([Edvinas-Smita](https://github.com/Edvinas-Smita))
- Fix Bleed damage multiplier when Enemy is moving [\#5](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/5) ([deathbeam](https://github.com/deathbeam))
- Fix export of uniques [\#44](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/44) ([TPlant](https://github.com/PJacek))
### Fixed Behaviours
- Fix Bleed not working with Spells [\#5](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/5) ([deathbeam](https://github.com/deathbeam))
- Fix Weapon Set passives on Tree not applying correctly [\#29](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/29) ([trompetin17](https://github.com/justjuangui))
- Fix slot-specific defence stat scaling [\#52](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/52) ([Edvinas-Smita](https://github.com/Edvinas-Smita))
- Fix Against the Darkness applying to all Jewel sockets [\#2](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/2) ([Peechey](https://github.com/Peechey))
- Fix The Adorned not increasing effect of Corrupted Magic Jewels [\#18](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/18) ([etojuice](https://github.com/etojuice))
- Fix Resistances not updating in sidebar [\#2](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/2) ([Peechey](https://github.com/Peechey))
- Fix Innervation not applying to other skills [\#23](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/23) ([LocalIdentity](https://github.com/LocalIdentity))
- Fix some Skills not including their guaranteed source of Ignite/Bleed/Poison [\#14](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/14) ([deathbeam](https://github.com/deathbeam))
- Fix some nodes on the tree not working with Ignite or fire damage [\#10](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/10) ([Nostrademous](https://github.com/Nostrademous))
- Fix Against the Darkness applying to Attribute nodes [\#24](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/24) ([Peechey](https://github.com/Peechey))
- Fix damage scaling with Mace Strike, Bow Shot, Concoction, and other skills [\#22](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/22) ([Peechey](https://github.com/Peechey))
- Fix Seismic Cry being treated as an Attack instead of a hit [\#42](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/42) ([LocalIdentity](https://github.com/LocalIdentity))
- Fix parsing for Grand Spectrum [\#46](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2-v2/pull/46) ([deathbeam](https://github.com/deathbeam))


Hello Exiles,

The Path of Building Community Team is happy to release the first version of Path of Building for Path of Exile 2

It was a lot  of work and there are sure to be an above-average number of bugs as many systems and interactions have
changed from PoE1 to PoE2.
At release of PoE2 Early Access a subset of the PoBCommunity team dug in and got to work carving
data/memory/assets/their-time like nobody's business in an effort to get this port put together.
It took us much longer than we anticipated (partially because many of us - to this day - highly enjoy playing PoE2 
and coding takes a back seat on some days; partially because it was Holiday Season; and partially because GGG did
not provide us with a Passive Skill Tree and the assets we normally have, so we had to go dig them up).

Huge thanks to: @LocalIdentity, @Nostrademous, @justjuangui, @PJacek, @sida-wang, @Peechey,
                @QuickStick123, @deathbeam, @Helyos96, @zao, @Wires77

In this version we are releasing the following initial features:
* PoE2 Passive Skill Tree and support for "most" Ascendancies (including Weapon Set Skill Points)
* Support for Attribute Switching on small passive tree nodes
* Basic support for most Skills and Supports gems with Stat Sets breakdowns for skills with multiple parts or effects
* Support for many (possibly all) known unique items
* Re-coded ailment calculations formula
* Much improved skill tree rendering engine
* Rune & Soul Core support
* Spirit and Spirit Reservation
* First-pass of an updated Configuration pane

A quick hit-list of things that ^1ARE NOT SUPPORTED ^7in this initial release:

* Character Importing - GGG has not yet enabled the API that will allow us to import characters
* Meta Skills / Trigger Skills damage calculation - this needs an entire overhaul we didn't have time to do thus far
* Skill Combos - it is our hope in the future to implement the concepts of "rotations" in a given skill
        i.e. the rotation of holding down the skill button in game, each one has slightly different speed, modifiers,
        and damage potential
        (e.g., Tempest Flurry: normal strike -> normal strike -> third strike -> final strike)     
* Weapon Set Swap combos
* Support for all Nodes / Modifiers / Ascendancies
        Many are supported, but not all - if a modifier on an item, tree node or ascendancy node is 'blue coloured' 
        we parse it - and hopefully support it - if it's 'red coloured' we do not.
* Proper support for Skills granted by Items
        We still need to complete the process of fully removing the concept of
        skill gems being tied to item sockets that was in PoE1 to allow for this, we just ran out of time
* Map Mods
* Boss Skills