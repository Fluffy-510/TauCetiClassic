//Previous code been here forever, adding new framework for portable generators


//Baseline portable generator. Has all the default handling. Not intended to be used on it's own (since it generates unlimited power).
/obj/machinery/power/port_gen
	name = "Placeholder Generator"	//seriously, don't use this. It can't be anchored without VV magic.
	desc = "A portable generator for emergency backup power."
	icon = 'icons/obj/power.dmi'
	var/icon_state_on = "gen_generic-on"
	icon_state = "gen_generic-off"
	density = TRUE
	anchored = FALSE
	use_power = NO_POWER_USE

	var/active = FALSE
	var/power_gen = 5000
	var/recent_fault = 0
	var/power_output = 1
	var/consumption = 0

/obj/machinery/power/port_gen/proc/HasFuel() //Placeholder for fuel check.
	return 1

/obj/machinery/power/port_gen/proc/UseFuel() //Placeholder for fuel use.
	return

/obj/machinery/power/port_gen/proc/DropFuel()
	return

/obj/machinery/power/port_gen/proc/handleInactive()
	return

/obj/machinery/power/port_gen/process()
	if(active && HasFuel() && !crit_fail && anchored && powernet)
		add_avail(power_gen * power_output)
		UseFuel()
		updateDialog()

	else
		active = FALSE
		icon_state = initial(icon_state)
		handleInactive()

/obj/machinery/power/port_gen/interact(mob/user)
	if(anchored)
		..()

/obj/machinery/power/port_gen/examine(mob/user)
	..()
	to_chat(user, "<span class='notice'>The generator is [active ? "on" : "off"].</span>")

//A power generator that runs on solid plasma sheets.
/obj/machinery/power/port_gen/pacman
	name = "P.A.C.M.A.N.-type Portable Generator"
	var/sheets = 0
	var/max_sheets = 100
	var/sheet_name = "solid phoron"
	var/sheet_path = /obj/item/stack/sheet/mineral/phoron
	var/board_path = /obj/item/weapon/circuitboard/pacman
	var/sheet_left = 0 // How much is left of the sheet
	var/time_per_sheet = 40
	var/heat = 0
	var/capacity_scale_with_upgrades = TRUE

/obj/machinery/power/port_gen/pacman/atom_init()
	. = ..()
	component_parts = list()
	component_parts += new /obj/item/weapon/stock_parts/matter_bin(src)
	component_parts += new /obj/item/weapon/stock_parts/micro_laser(src)
	component_parts += new /obj/item/stack/cable_coil/red(src, 1)
	component_parts += new /obj/item/stack/cable_coil/red(src, 1)
	component_parts += new /obj/item/weapon/stock_parts/capacitor(src)
	component_parts += new board_path(src)
	RefreshParts()

/obj/machinery/power/port_gen/pacman/atom_init()
	. = ..()
	if(anchored)
		connect_to_network()

/obj/machinery/power/port_gen/pacman/Destroy()
	DropFuel()
	return ..()

/obj/machinery/power/port_gen/pacman/RefreshParts()
	..()

	var/temp_rating = 0
	var/consumption_coeff = 0
	for(var/obj/item/weapon/stock_parts/SP in component_parts)
		if(istype(SP, /obj/item/weapon/stock_parts/matter_bin) && capacity_scale_with_upgrades)
			max_sheets = SP.rating * SP.rating * 50
		else if(istype(SP, /obj/item/weapon/stock_parts/capacitor))
			temp_rating += SP.rating
		else
			consumption_coeff += SP.rating
	power_gen = round(initial(power_gen) * temp_rating * 2)
	consumption = consumption_coeff

/obj/machinery/power/port_gen/pacman/examine(mob/user)
	..()
	to_chat(user, "<span class='notice'>The generator has [sheets] units of [sheet_name] fuel left, producing [power_gen] per cycle.</span>")
	if(crit_fail)
		to_chat(user, "<span class='danger'>The generator seems to have broken down.</span>")

/obj/machinery/power/port_gen/pacman/HasFuel()
	if(sheets >= 1 / (time_per_sheet / power_output) - sheet_left)
		return 1
	return 0

/obj/machinery/power/port_gen/pacman/DropFuel()
	if(sheets)
		var/fail_safe = 0
		while(sheets > 0 && fail_safe < 100)
			fail_safe += 1
			var/obj/item/stack/sheet/S = new sheet_path(loc)
			var/amount = min(sheets, S.max_amount)
			S.set_amount(amount)
			sheets -= amount

/obj/machinery/power/port_gen/pacman/UseFuel()
	var/needed_sheets = 1 / (time_per_sheet * consumption / power_output)
	var/temp = min(needed_sheets, sheet_left)
	needed_sheets -= temp
	sheet_left -= temp
	sheets -= round(needed_sheets)
	needed_sheets -= round(needed_sheets)
	if (sheet_left <= 0 && sheets > 0)
		sheet_left = 1 - needed_sheets
		sheets--

	var/lower_limit = 56 + power_output * 10
	var/upper_limit = 76 + power_output * 10
	var/bias = 0
	if (power_output > 4)
		upper_limit = 400
		bias = power_output - consumption * (4 - consumption)
	if (heat < lower_limit)
		heat += 4 - consumption
	else
		heat += rand(-7 + bias, 7 + bias)
		if (heat < lower_limit)
			heat = lower_limit
		if (heat > upper_limit)
			heat = upper_limit

	if (heat > 300)
		overheat()
		qdel(src)
	return

/obj/machinery/power/port_gen/pacman/handleInactive()

	if (heat > 0)
		heat = max(heat - 2, 0)
		updateDialog()

/obj/machinery/power/port_gen/pacman/proc/overheat()
	explosion(src.loc, 2, 5, 2, -1)

/obj/machinery/power/port_gen/pacman/proc/add_sheets(obj/item/I, mob/user, params)
	var/obj/item/stack/addstack = I
	var/amount = min((max_sheets - sheets), addstack.get_amount())
	if(amount < 1)
		to_chat(user, "<span class='notice'>The [name] is full!</span>")
		return
	to_chat(user, "<span class='notice'>You add [amount] sheets to the [name].</span>")
	sheets += amount
	addstack.use(amount)
	playsound(src, 'sound/items/insert_key.ogg', VOL_EFFECTS_MASTER)

/obj/machinery/power/port_gen/pacman/attackby(obj/item/O, mob/user, params)
	if(istype(O, sheet_path))
		add_sheets(O, user, params)
		updateUsrDialog()
	else if(!active)

		if(exchange_parts(user, O))
			return

		if(iswrenching(O))

			if(!anchored && !isinspace())
				connect_to_network()
				to_chat(user, "<span class='notice'>You secure the generator to the floor.</span>")
				anchored = TRUE
			else if(anchored)
				disconnect_from_network()
				to_chat(user, "<span class='notice'>You unsecure the generator from the floor.</span>")
				anchored = FALSE

			playsound(src, 'sound/items/Deconstruct.ogg', VOL_EFFECTS_MASTER)

		else if(isscrewing(O))
			panel_open = !panel_open
			playsound(src, 'sound/items/Screwdriver.ogg', VOL_EFFECTS_MASTER)
			if(panel_open)
				to_chat(user, "<span class='notice'>You open the access panel.</span>")
			else
				to_chat(user, "<span class='notice'>You close the access panel.</span>")
		else if(isprying(O) && panel_open)
			default_deconstruction_crowbar(O)

/obj/machinery/power/port_gen/pacman/emag_act(mob/user)
	if(emagged)
		return FALSE
	emagged = 1
	user.SetNextMove(CLICK_CD_INTERACT)
	emp_act(1)
	return TRUE

/obj/machinery/power/port_gen/pacman/ui_interact(mob/user)
	if ((get_dist(src, user) > 1) && !issilicon(user) && !isobserver(user))
		user.unset_machine(src)
		user << browse(null, "window=port_gen")
		return

	var/dat = ""
	if (active)
		dat += text("Generator: <A href='byond://?src=\ref[src];action=disable'>On</A><br>")
	else
		dat += text("Generator: <A href='byond://?src=\ref[src];action=enable'>Off</A><br>")
	dat += text("[capitalize(sheet_name)]: [sheets] - <A href='byond://?src=\ref[src];action=eject'>Eject</A><br>")
	var/stack_percent = round(sheet_left * 100, 1)
	dat += text("Current stack: [stack_percent]% <br>")
	dat += text("Power output: <A href='byond://?src=\ref[src];action=lower_power'>-</A> [power_gen * power_output] <A href='byond://?src=\ref[src];action=higher_power'>+</A><br>")
	dat += text("Power current: [(powernet == null ? "Unconnected" : "[avail()]")]<br>")
	dat += text("Heat: [heat]<br>")

	var/datum/browser/popup = new(user, "port_gen", src.name)
	popup.set_content(dat)
	popup.open()

/obj/machinery/power/port_gen/pacman/is_operational()
	return TRUE

/obj/machinery/power/port_gen/pacman/Topic(href, href_list)
	. = ..()
	if(!.)
		return

	if(href_list["action"])
		if(href_list["action"] == "enable")
			if(!active && HasFuel() && !crit_fail)
				active = TRUE
				icon_state = icon_state_on
				playsound(src, 'sound/machines/pacman_on.ogg', VOL_EFFECTS_MASTER)
		if(href_list["action"] == "disable")
			if (active)
				active = FALSE
				icon_state = initial(icon_state)
				playsound(src, 'sound/machines/pacman_off.ogg', VOL_EFFECTS_MASTER)
		if(href_list["action"] == "eject")
			if(!active)
				DropFuel()
		if(href_list["action"] == "lower_power")
			if (power_output > 1)
				power_output--
		if (href_list["action"] == "higher_power")
			if (power_output < 4 || emagged)
				power_output++

	updateUsrDialog()


/obj/machinery/power/port_gen/pacman/super
	name = "S.U.P.E.R.P.A.C.M.A.N.-type Portable Generator"
	icon_state = "gen_uranium-off"
	icon_state_on = "gen_uranium-on"
	sheet_name = "uranium"
	sheet_path = /obj/item/stack/sheet/mineral/uranium
	power_gen = 15000
	time_per_sheet = 65
	board_path = /obj/item/weapon/circuitboard/pacman/super

/obj/machinery/power/port_gen/pacman/super/overheat()
	explosion(src.loc, 3, 3, 3, -1)

/obj/machinery/power/port_gen/pacman/mrs
	name = "M.R.S.P.A.C.M.A.N.-type Portable Generator"
	icon_state = "gen_uranium-off"
	icon_state_on = "gen_uranium-on"
	sheet_name = "tritium"
	sheet_path = /obj/item/stack/sheet/mineral/tritium
	power_gen = 40000
	time_per_sheet = 80
	board_path = /obj/item/weapon/circuitboard/pacman/mrs

/obj/machinery/power/port_gen/pacman/mrs/overheat()
	explosion(src.loc, 4, 4, 4, -1)

/obj/machinery/power/port_gen/pacman/money
	name = "A.N.C.A.P.M.A.N.-type Portable Generator"
	desc = "Don't simply waste your money - burn them to get power instead!"
	icon_state = "gen_money-off"
	icon_state_on = "gen_money-on"
	sheet_name = "cash"
	sheet_path = /obj/item/weapon/spacecash
	power_gen = 10000
	max_sheets = 10000
	time_per_sheet = 5
	board_path = /obj/item/weapon/circuitboard/pacman/money
	capacity_scale_with_upgrades = FALSE

/obj/machinery/power/port_gen/pacman/money/add_sheets(obj/item/I, mob/user, params)
	var/obj/item/weapon/spacecash/addstack = I
	var/amount = min((max_sheets - sheets), addstack.worth)
	if(amount < 1)
		to_chat(user, "<span class='notice'>The [name] is full!</span>")
		return
	to_chat(user, "<span class='notice'>You add [amount] sheets to the [name].</span>")
	sheets += amount
	qdel(addstack)

/obj/machinery/power/port_gen/pacman/money/overheat()
	visible_message("<span class='notice'>[src] overheats and quietly disintegrates. No customer should ever worry!</span>")
	qdel(src)
