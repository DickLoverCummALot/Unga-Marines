/obj/item/beacon
	w_class = WEIGHT_CLASS_SMALL
	/// If this beacon is activated
	var/activated = FALSE
	/// How long to activate this beacon
	var/activation_time = 80
	/// The icon when acticated
	var/icon_activated = ""
	/// The camera attached to the beacon
	var/obj/machinery/camera/beacon_cam = null
	///Can work underground
	var/underground_signal = FALSE
	///Beacon minimap icon
	var/beacon_mini_icon = null

/obj/item/beacon/update_icon_state()
	. = ..()
	icon_state = activated ? icon_activated : initial(icon_state)

/obj/item/beacon/attack_self(mob/living/carbon/human/H)
	if(!istype(H))
		return
	activate(H)

/obj/item/beacon/attack_hand(mob/living/carbon/human/H)
	if(!ishuman(H))
		return ..()
	if(activated)
		deactivate(H)
		return
	return ..()

/// Set this beacon on the ground and activate it
/obj/item/beacon/proc/activate(mob/living/carbon/human/H)
	if(!is_ground_level(H.z))
		to_chat(H, span_warning("You have to be on the planet to use this or it won't transmit."))
		return FALSE
	var/area/A = get_area(H)
	if(A && istype(A) && A.ceiling >= CEILING_DEEP_UNDERGROUND && !underground_signal)
		to_chat(H, span_warning("This won't work if you're standing deep underground."))
		return FALSE
	if(istype(A, /area/shuttle/dropship))
		to_chat(H, span_warning("You have to be outside the dropship to use this or it won't transmit."))
		return FALSE
	var/delay = max(1.5 SECONDS, activation_time - 2 SECONDS * H.skills.getRating(SKILL_LEADERSHIP))
	H.visible_message(span_notice("[H] starts setting up [src] on the ground."),
	span_notice("You start setting up [src] on the ground and inputting all the data it needs."))
	if(!do_after(H, delay, NONE, src, BUSY_ICON_GENERIC))
		return FALSE
	var/obj/machinery/camera/beacon_cam/BC = new(src, "[H.get_paygrade()] [H.name] [src]")
	H.transferItemToLoc(src, H.loc)
	beacon_cam = BC
	message_admins("[ADMIN_TPMONTY(usr)] set up a supply beacon.")
	name = "transmitting orbital beacon - [get_area(src)] - [H]"
	activated = TRUE
	anchored = TRUE
	w_class = WEIGHT_CLASS_GIGANTIC
	layer = ABOVE_FLY_LAYER
	set_light(2, 1)
	playsound(src, 'sound/machines/twobeep.ogg', 15, 1)
	H.visible_message("[H] activates [src].",
	"You activate [src].")

	var/marker_flags = GLOB.faction_to_minimap_flag[H.faction]
	if(!marker_flags)
		marker_flags = MINIMAP_FLAG_MARINE
	//RUTGMC EDIT CHANGE BEGIN - ORBITAL_BEACON
	//SSminimaps.add_marker(src, marker_flags, image('icons/UI_icons/map_blips.dmi', null, "supply")) RUTGMC  EDIT - ORIGINAL
	SSminimaps.add_marker(src, marker_flags, image('icons/UI_icons/map_blips.dmi', null, beacon_mini_icon, ABOVE_FLOAT_LAYER))
	//RUTGMC EDIT CHANGE END
	update_icon()
	return TRUE

/// Deactivate this beacon and put it in the hand of the human
/obj/item/beacon/proc/deactivate(mob/living/carbon/human/H)
	var/delay = max(1 SECONDS, activation_time * 0.5 - 2 SECONDS * H.skills.getRating(SKILL_LEADERSHIP)) //Half as long as setting it up.
	H.visible_message(span_notice("[H] starts removing [src] from the ground."),
	span_notice("You start removing [src] from the ground, deactivating it."))
	if(!do_after(H, delay, NONE, src, BUSY_ICON_GENERIC))
		return FALSE
	QDEL_NULL(beacon_cam)
	activated = FALSE
	anchored = FALSE
	w_class = initial(w_class)
	layer = initial(layer)
	name = initial(name)
	set_light(0)
	playsound(src, 'sound/machines/twobeep.ogg', 15, 1)
	H.visible_message("[H] deactivates [src].",
	"You deactivate [src].")
	H.put_in_active_hand(src)
	SSminimaps.remove_marker(src)
	update_icon()
	return TRUE

/obj/item/beacon/Destroy()
	if(beacon_cam)
		qdel(beacon_cam)
		beacon_cam = null
	return ..()

/obj/item/beacon/supply_beacon
	name = "supply beacon"
	desc = "A rugged, glorified laser pointer capable of sending a beam into space. Activate and throw this to call for a supply drop."
	icon = 'icons/Marine/marine-navigation.dmi'
	icon_state = "motion0"
	icon_activated = "motion2"
	activation_time = 60
	beacon_mini_icon = "supply"
	/// Reference to the datum used by the supply drop console
	var/datum/supply_beacon/beacon_datum

/obj/item/beacon/supply_beacon/Destroy()
	if(beacon_datum)
		UnregisterSignal(beacon_datum, COMSIG_QDELETING)
		QDEL_NULL(beacon_datum)
	return ..()

/// Signal handler to nullify beacon datum
/obj/item/beacon/supply_beacon/proc/clean_beacon_datum()
	SIGNAL_HANDLER
	beacon_datum = null

/obj/item/beacon/supply_beacon/on_changed_z_level(old_turf, new_turf, notify_contents)
	. = ..()
	//Assumes doMove sets loc before onTransitZ
	if(beacon_datum)
		beacon_datum.drop_location = loc

/obj/item/beacon/supply_beacon/activate(mob/living/carbon/human/H)
	var/area/A = get_area(H)
	. = ..()
	if(!.)
		return
	beacon_datum = new /datum/supply_beacon("[H.name] + [A]", loc, H.faction)
	RegisterSignal(beacon_datum, COMSIG_QDELETING, PROC_REF(clean_beacon_datum))

/obj/item/beacon/supply_beacon/deactivate(mob/living/carbon/human/H)
	. = ..()
	if(!.)
		return
	UnregisterSignal(beacon_datum, COMSIG_QDELETING)
	QDEL_NULL(beacon_datum)

/datum/supply_beacon
	/// Name printed on the supply console
	var/name = ""
	/// Where the supply drops will land
	var/turf/drop_location
	/// The faction of the beacon
	var/faction = ""

/datum/supply_beacon/New(_name, turf/_drop_location, _faction, life_time = 0 SECONDS)
	name =  _name
	drop_location = _drop_location
	faction = _faction
	GLOB.supply_beacon[name] = src
	if(life_time)
		QDEL_IN(src, life_time)

/// Remove that beacon from the list of glob supply beacon
/datum/supply_beacon/Destroy()
	GLOB.supply_beacon -= name
	return ..()

/obj/item/beacon/orbital_bombardment_beacon
	name = "orbital beacon"
	desc = "A bulky device that fires a beam up to an orbiting vessel to send local coordinates."
	icon = 'icons/Marine/marine-navigation.dmi'
	icon_state = "motion4"
	icon_activated = "motion1"
	underground_signal = FALSE
	beacon_mini_icon = "ob_beacon"
	///The squad this OB beacon belongs to
	var/datum/squad/squad = null

/obj/item/beacon/orbital_bombardment_beacon/activate(mob/living/carbon/human/H)
	. = ..()
	if(!.)
		return
	if(H.assigned_squad)
		squad = H.assigned_squad
		name += " ([squad.name])"
		squad.squad_orbital_beacons += src
		name += " ([H])"
		GLOB.active_orbital_beacons += src
		return
	else	//So we can just get a goshdarn name.
		name += " ([H])"
		GLOB.active_orbital_beacons += src
	message_admins("[ADMIN_TPMONTY(usr)] set up an orbital strike beacon.")

/obj/item/beacon/orbital_bombardment_beacon/deactivate(mob/living/carbon/human/H)
	. = ..()
	if(!.)
		return
	squad?.squad_orbital_beacons -= src
	squad = null
	GLOB.active_orbital_beacons -= src

/obj/item/beacon/orbital_bombardment_beacon/Destroy()
	squad?.squad_orbital_beacons -= src
	squad = null
	GLOB.active_orbital_beacons -= src
	return ..()
