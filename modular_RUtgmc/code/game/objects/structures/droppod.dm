/obj/structure/droppod/launch_pod(mob/user)
	. = ..()
	var/turf/target = locate(target_x, target_y, 2)
	var/obj/effect/overlay/blinking_laser/marine/pod_warning/laserpod = new /obj/effect/overlay/blinking_laser/marine/pod_warning(target)
	laserpod.dir = target
	QDEL_IN(laserpod, DROPPOD_TRANSIT_TIME + 1)
