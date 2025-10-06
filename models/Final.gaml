/**
* Name: part1
* Load graphical scenario 
* Author: Liliana Durán Polanco
* Tags: 
*/


model part1

global
{
	// Maps and images declaration
	file 		shp_roads 		<- file("../includes/maps/cd_creativa_1.shp");
	file 		shp_nodes 		<- file("../includes/maps/cd_creativa_nodes_1.shp");
	file 		shp_building 	<- file("../includes/maps/cd_creativa_build_2.shp");
	
	file 		shp_mibici 		<- file("../includes/maps/mibici_spots.shp");
	image_file 	logo_mibici 	<- image_file("../includes/img/mibici_logo.png");
	
	
	geometry 	shape 			<- envelope(shp_roads);
	graph 		road_network;
	
	map<string,int> building_type 		<- ["Lugar trabajo"::1,"Negocio tradicional"::2, "Nuevo negocio"::3, "Centro cultural"::4];
	map<string,int> economic_profile 	<- ["Bajo"::1, "Medio"::2, "Alto"::3]; 
	map<string,int> transport_type		<- ["Peaton"::1, "Auto"::2,  "MiBici"::3];
	

	//int number_of_work_places 		<- 10;
	int number_of_traditional		<- 100;
	int number_of_new_places		<- 80;
	int number_of_cultural			<- 8;
	
	int number_of_low_profile		<- 0;
	int number_of_mid_profile		<- 0;
	int number_of_high_profile		<- 1000;
	
	
	
	list<building> traditional;
	list<building> new_places;
	list<building> cultural; 
	
	//step <- 1#minute;
	
	field cell <- field(300,300);
	
	
	init
	{
		step <- 10 #s;
		create intersection from: shp_nodes;
		create road 		from:shp_roads where (each != nil);
		
		road_network 		<- as_driving_graph(road, intersection);

		
		create mibici 	from: shp_mibici;
		
		create building from:shp_building 
		{
			type <- "Lugar trabajo";
		}
		
		
		create car number:200;
		
		
		loop element over:building
		{
			if number_of_cultural > 0
			{
				element.type <- "Centro cultural";
				add element to: cultural;
				number_of_cultural		<- number_of_cultural-1;
			}
			
			else if number_of_new_places > 0
			{
				element.type <- "Nuevo negocio";
				add element to: new_places;
				number_of_new_places	<- number_of_new_places-1;
			}
			else if number_of_traditional > 0
			{
				element.type <- "Negocio tradicional";
				add element to: traditional;
				number_of_traditional	<- number_of_traditional-1;
			}
			else
			{
				break;
			}
		}
		
	
		create person number: number_of_low_profile 
		{ 
			profile 			<-"Bajo";
			location 			<- any_location_in(one_of(building));
			bussiness_preference<- ["Negocio tradicional"::0.85, "Nuevo negocio"::0.1, "Centro cultural"::0.05];
			transport_preference<- ["Peaton"::rnd(0.5,1.0), "Auto"::rnd(0.0,0.2), "MiBici"::rnd(0.0,1.0)];	
		}
		
		create person number: number_of_mid_profile 
		{ 
			profile 			<- "Medio";
			location 			<- any_location_in(one_of(building));
			bussiness_preference<- ["Negocio tradicional"::0.3, "Nuevo negocio"::0.6, "Centro cultural"::0.1];
			transport_preference<- ["Peaton"::rnd(0.5,1.0), "Auto"::rnd(0.0,0.7), "MiBici"::rnd(0.0,1.0)];
		}
		
		create person number: number_of_high_profile 
		{ 
			profile 			<- "Alto";
			location 			<- any_location_in(one_of(building));
			bussiness_preference<- ["Negocio tradicional"::0.1, "Nuevo negocio"::0.7, "Centro cultural"::0.2];
			transport_preference<- ["Peaton"::rnd(0.0,0.5), "Auto"::rnd(0.5,0.1), "MiBici"::rnd(0.0,1.0)];
		}
		
		
	}
	
	//Reflex to decrease and diffuse the heat
	reflex heat_evolution {
		//ask all cells to decrease their heat level
		cell <- cell * 0.8;
	
		//diffuse the heat to neighbor cells
		diffuse var: heat on: cell proportion: 0.9;
	}
	
}


species building
{
	string type;
	int FID;
	int person_count <-  length(agents_overlapping(self)) update:  length(agents_overlapping(self)) ;
	map<string,rgb> colors <- ["Lugar trabajo"::#darkgrey,"Negocio tradicional"::#deepskyblue, "Nuevo negocio"::#darkmagenta, "Centro cultural"::#royalblue];

	
	aspect default
	{
		draw shape color: darker(colors[type]).darker depth: rnd(10) + 2;
	}
}

species road skills: [road_skill]
{
	aspect default
	{
		draw (shape + 5#m) color: #white;
	}
}

species intersection skills: [intersection_skill] ;

species mibici 
{
	aspect default
	{
		pair<float,point> r0 	<-  -90::{1,0,0};	
		draw cube(10) at:location;
		draw logo_mibici size:20 at:location+{0,0,20} rotate: r0;
	}
}

species person skills: [moving]
{
	string 	profile;
	bool	relocate_active; // 
	map<string,float>	bussiness_preference;
	map<string,float>	transport_preference;
	
	//Target point of the agent
	string			transport;
	point 			target;
	map<int,point> 	route ;
	
	
	//Probability of leaving the building
	float 	leaving_proba <- 0.2;
	//Speed of the agent
	float 	speed <- rnd(10) #km / #h + 1;
	// Random state
	string 	state <- "in_place"; // on_route, in_place, on_route_inter
	int	 	r_step;
	
	
	//Reflex to leave the building to another building
	reflex leave when: (target = nil) and (flip(leaving_proba)) and (state="in_place") {
		string  target_type <- rnd_choice(bussiness_preference);
		
		target 		<-  any_location_in(one_of(building where (each.type=target_type)));
		transport 	<-	rnd_choice(transport_preference);
		
		
		switch transport
		{ 
			match "Peaton"
			{
				add 1::target	to: route;
				
				state <- "on_route";
			}
			match "Auto"
			{
				add 1::target 	to: route;
				
				state <- "on_route";
			}
			match "MiBici"
			{
				add 1::closest_to(mibici, self).location to:route; 	//start
				add 2::closest_to(mibici, target).location 		 to:route; 
				add 3::target 							 to:route;	// end
				
				state <- "on_route_inter";
			}
		}
		
		r_step <- 1;
		target <- route[r_step];
		do change_speed;
	}
	

	//Reflex to move to the target building moving on the road network
	reflex move when: (target != nil and state != "in_place") {
		path path_followed <- goto(target: target, on: road_network, recompute_path: true, return_path: true);

		if (path_followed != nil and path_followed.shape != nil and transport="MiBici") {
			cell[path_followed.shape.location] <- cell[path_followed.shape.location] + 10;					
		}

		
		if (location = target) 
		{
			
			if length(route) > 0
			{
				remove key:r_step from: route;
				r_step  <- r_step+1;
				target 	<- route[r_step];
				state	<- target = nil ? "in_place" : (r_step mod 2 = 0 ? "on_route" : "on_route_inter");
				do change_speed;
			}
			else
			{
				route <- [];
				transport 	<- "Peaton";
				state 		<- "in_place";
				do change_speed;
			}
		} 
	}



	reflex relocate when: current_path = nil and target != nil
	{
		point point_relocate <- any_location_in(one_of(intersection));//(intersection closest_to(self)).location;
		location <- point_relocate;
	}


	action change_speed
	{
		if state = "on_route"
		{
			switch(transport)
			{
				match "Auto"
				{
					speed <- rnd(50,100) #km / #h + 1;
				}
				match "MiBici"
				{
					speed <- rnd(10,30) #km / #h + 1;
				}
			}
		}
		else
		{
			speed <- rnd(10) #km / #h + 1;
		}	
	}
	
	aspect default 
	{
		if state = "on_route"
		{
			switch(transport)
			{
				match "Auto"
				{
					draw rectangle(4,10) rotated_by (heading+90) color:( #lawngreen) depth: 3;
					draw rectangle(4, 6) rotated_by (heading+90) color:( #lawngreen) depth: 4;
				}
				match "MiBici"
				{
					draw rectangle(1,3) rotated_by (heading+90) color: #deeppink depth: 2;
				}
			}
		}
		else
		{
			draw sphere(1) color: #mediumturquoise;
		}	
	} 
}



species car skills: [driving] 
{
	init 
	{
		location <- one_of(intersection).location;
		vehicle_length <- 1.9 #m;
		max_speed <- rnd(50,100) #km / #h;
		max_acceleration <- 3.5;
		
	}
	
	reflex relocate when: next_road = nil and distance_to_current_target = 0.0 {
		do unregister;
		location <- one_of(intersection).location;
	}

	reflex select_next_path when: current_path = nil {
		intersection goal <- one_of(intersection);
		
		loop while: goal.location = location 
		{
			goal <- one_of(intersection);
		}
		
		do compute_path graph: road_network target: goal;
	}
	
	
	reflex commute when: current_path != nil {
		do drive;
	}
	
	aspect default 
	{
		draw rectangle(4,10) rotated_by (heading+90) color:( #dodgerblue) depth: 3;
		draw rectangle(4, 6) rotated_by (heading+90) color:( #dodgerblue) depth: 4;
	} 
}

experiment main type:gui
{
	parameter "Bajo" 	category:"Población por perfil socio economico" var: number_of_low_profile	;
	parameter "Medio" 	category:"Población por perfil socio economico" var: number_of_mid_profile	;
	parameter "Alto" 	category:"Población por perfil socio economico" var: number_of_high_profile ;
	
	map<string,rgb> colors <- ["Lugar trabajo"::#darkgrey,"Negocio tradicional"::#deepskyblue, "Nuevo negocio"::#darkmagenta, "Centro cultural"::#royalblue];
	list<rgb> pal <- palette([ #black, #green, #yellow, #orange, #orange, #red, #red, #red]);
	
	output synchronized: true
	{
		layout #split;
		
		display traffic type: 3d axes: false background: rgb(50,50,50) toolbar: false {
			light #ambient intensity: 128;
			camera 'default' location: {1254.041,2938.6921,1792.4286} target: {1258.8966,1547.6862,0.0};
			species road 	 refresh: false;
			species building refresh: false;
			species mibici 	 refresh: false;
			species person 	 refresh: true;
			species car		 refresh: true;
			
			mesh cell scale: 9 triangulation: true transparency: 0.4 smooth: 3 above: 0.8 color: pal;
		}
		
		
		display "Uso de transporte" type:2d {
			chart "Uso de transporte" type:histogram 
			style:stack
			x_serie_labels:("cycle"+cycle)
			x_range:5
			{
				data "Peaton" 	value: length(person where (each.transport="Peaton" and each.state!="in_place"))
					accumulate_values: true						
					color:#mediumturquoise;
				data "MiBici" 	value: length(person where (each.transport="MiBici" and each.state!="in_place"))
					accumulate_values: true						
					color:#deeppink;
				data "Auto" 	value: length(person where (each.transport="Auto" and each.state!="in_place"))
					accumulate_values: true	
					color:#lawngreen			
				marker_shape:marker_circle ;
			}
		} 
		
		display "Demanda negocios" type: 2d
		{
			chart "Demanda negocios" type: pie style: 3d
			{
				data "Negocio tradicional" 	value: traditional sum_of(each.person_count)/length(person) color: colors["Negocio tradicional"];
				data "Nuevo negocio" 		value: new_places  sum_of(each.person_count)/length(person) color: colors["Nuevo negocio"];
				data "Centro cultural" 		value: cultural    sum_of(each.person_count)/length(person) color: colors["Centro cultural"];
			}

		}
	
	
		
	}
	
	
}


