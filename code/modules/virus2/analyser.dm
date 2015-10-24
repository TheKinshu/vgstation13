/obj/machinery/disease2/diseaseanalyser
	name = "Disease Analyser"
	desc = "For analysing and storing viral samples"
	icon = 'icons/obj/virology.dmi'
	icon_state = "analyser"
	anchored = 1
	density = 1
	machine_flags = SCREWTOGGLE | CROWDESTROY

	var/scanning = 0
	var/pause = 0
	var/process_time = 5
	var/minimum_growth = 50
	var/list/toscan = new //List of samples to analyse
	var/obj/item/weapon/virusdish/dish = null //Repurposed to mean 'dish currently being analysed'

/obj/machinery/disease2/diseaseanalyser/New()
	. = ..()
	component_parts = newlist(
		/obj/item/weapon/circuitboard/diseaseanalyser,
		/obj/item/weapon/stock_parts/manipulator,
		/obj/item/weapon/stock_parts/micro_laser,
		/obj/item/weapon/stock_parts/scanning_module,
		/obj/item/weapon/stock_parts/scanning_module,
		/obj/item/weapon/stock_parts/scanning_module,
	)

	RefreshParts()

/obj/machinery/disease2/diseaseanalyser/RefreshParts()
	var/scancount = 0
	var/lasercount = 0
	for(var/obj/item/weapon/stock_parts/SP in component_parts)
		if(istype(SP, /obj/item/weapon/stock_parts/scanning_module)) scancount += SP.rating-1
		if(istype(SP, /obj/item/weapon/stock_parts/micro_laser)) lasercount += SP.rating-1
	minimum_growth = initial(minimum_growth) - (scancount * 3)
	process_time = initial(process_time) - lasercount

/obj/machinery/disease2/diseaseanalyser/attackby(var/obj/I as obj, var/mob/user as mob)
	..()
	if(istype(I,/obj/item/weapon/virusdish))
		var/mob/living/carbon/c = user
		var/obj/item/weapon/virusdish/D = I
		if(!D.analysed)
			if(!dish)
				dish = D
			else
				toscan += D
		c.drop_item(D, src)
		for(var/mob/M in viewers(src))
			if(M == user)	continue
			M.show_message("<span class='notice'>[user.name] inserts the [D.name] in the [src.name]</span>", 3)
	return

/obj/machinery/disease2/diseaseanalyser/proc/PrintPaper(var/obj/item/weapon/virusdish/D)
	var/obj/item/weapon/paper/P = new /obj/item/weapon/paper(src.loc)
	//var/r = D.virus2.get_info()
	P.info = D.virus2.get_info()
	P.name = "Virus #[D.virus2.uniqueID]"
	visible_message("\The [src.name] prints a sheet of paper")
	return

/obj/machinery/disease2/diseaseanalyser/proc/Analyse(var/obj/item/weapon/virusdish/D)
	dish.info = D.virus2.get_info()
	dish.analysed = 1
	if (D.virus2.addToDB())
		say("Added new pathogen to database.")
	PrintPaper(dish)
	dish.loc = src.loc
	dish = null
	icon_state = "analyser"
	return

/obj/machinery/disease2/diseaseanalyser/process()
	if(stat & (NOPOWER|BROKEN))
		return
	use_power(500)

	if(scanning)
		scanning -= 1
		if(scanning == 0)
			Analyse(dish)
	else if((dish || toscan.len > 0) && !scanning && !pause)
		if(!dish)
			dish = toscan[1] //Load next dish to analyse
			toscan -= dish //Remove from scanlist
		if(dish.virus2 && dish.growth > minimum_growth)
			dish.growth -= 10
			scanning = process_time
			icon_state = "analyser_processing"
		else
			pause = 1
			spawn(25)
				dish.loc = src.loc
				dish = null
				alert_noise("buzz")
				pause = 0
	return

/obj/machinery/disease2/diseaseanalyser/Topic(href, href_list)
	if(..())
		return
	if (!usr.canmove || usr.stat || usr.restrained() || !in_range(loc, usr))
		usr.unset_machine()
		usr << browse(null, "window=computer")
		return
	if(usr) usr.set_machine(src)

	if(href_list["eject"])
		for(var/obj/item/weapon/virusdish/O in src.contents)
			if("[O.virus2.uniqueID]" == href_list["name"])
				O.loc = src.loc
				toscan -= O
		src.updateUsrDialog()
	else if(href_list["scan"])
		for(var/obj/item/weapon/virusdish/O in src.contents)
			if("[O.virus2.uniqueID]" == href_list["name"])
				if(!toscan["O"])
					toscan += O
	else if(href_list["print"])
		for(var/obj/item/weapon/virusdish/O in src.contents)
			if("[O.virus2.uniqueID]" == href_list["name"])
				PrintPaper(O)
	else if(href_list["close"])
		usr << browse(null, "window=computer")
	return

/obj/machinery/disease2/diseaseanalyser/attack_hand(var/mob/user as mob)
	user.set_machine(src)
	var/dat
	dat = " Viral Storage & Analysis Unit V1.3"
	dat += "<BR>Currently stored samples: [src.contents.len]"
	if (src.contents.len > 0)
		dat += "<table cellpadding='2' style='width: 100%;text-align:center;'><td>Name</td><td>Symptoms</td><td>Antibodies</td><td>Transmission</td><td>Options</td>"
		for(var/obj/item/weapon/virusdish/B in src.contents)
			//if(B == toscan[B])
			var/ID = B.virus2.uniqueID
			if("[ID]" in virusDB)
				var/datum/data/record/v = virusDB["[ID]"]
				dat += "<BR><tr><td>[v.fields["name"]]</td>"
				dat+="<td>"
				for(var/datum/disease2/effectholder/e in B.virus2.effects)
					dat += "<br>[e.effect.name]"
				dat+="</td>"
				dat += "<td>[v.fields["antigen"]]</td>"
				dat += "<td>[v.fields["spread type"]]</td>"
			else
				if(B == dish) //Analysing
					dat += "<br><tr><td>Analysing Sample.</td><td></td><td></td><td></td>"
				else
					dat += "<br><tr><td>Sample not in database.</td><td></td><td></td><td></td>"
			dat += "<td>"
			if(B == dish)
				dat += "</td></tr>"
			else
				dat += "<A href='?src=\ref[src];eject=1;name=["[ID]"];'>Eject</a>" //Disallow ejection if the sample is being analysed
				dat += "[B.analysed ? "<br><A href='?src=\ref[src];print=1;name=["[ID]"];'>Print</a></td>" : "<br><A href='?src=\ref[src];scan=1;name=["[ID]"];'>Analyse</a></td>"]</tr>"
		dat += "</table>"
	dat += "<BR><A href='?src=\ref[src];close=1'>Close</a>"
	user << browse("<TITLE>Disease Analyser</TITLE>[dat]", "window=computer;size=600x350")
	onclose(user, "computer")
	return