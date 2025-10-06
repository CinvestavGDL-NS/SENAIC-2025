/**
* Name: GENTRIFICACIÓN Y USO DE TRANSPORTE
* Load graphical scenario 
* Author: Liliana Durán Polanco, Giovana Perez Carrillo & Diego Orozco Castillo
* Tags: 
*/


model gentrif_model_part7

global
{
	// Se declaran los mapas y se carga la información pertinente.
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
	

	// Se definen los posibles destinos (lugares de interés para los agentes)
	int number_of_traditional			<- 100;
	int number_of_new_places		<- 80;
	int number_of_cultural				<- 20;
	
	
	// Se definen la cantidad de agentes de cada tipo
	int number_of_low_profile			<- 500;
	int number_of_mid_profile		<- 500;
	int number_of_high_profile		<- 2000;
	
	list<building> traditional;
	list<building> new_places;
	list<building> cultural; 
	
	// variables adicionales
	int number_of_bici						<- 650 min:0;
	bool bici_available<- true;
	int traffic_level_app;
	int traffic_base	<- 200;
	bool gentrificacion <- false;
	bool interaction_intervention <- true;
	
	
	
	// Celdas para el mapa de calor
	field cell <- field(300,300);
	
	//Inicialización de la simulación
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
		
		
		create car number:traffic_base;
		
		
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
			bussiness_preference<- ["Negocio tradicional"::0.7, "Nuevo negocio"::0.25, "Centro cultural"::0.05];
			transport_preference<- ["Peaton"::0.3, "Auto"::0.1, "MiBici_prob"::0.6];	
		}
		
		create person number: number_of_mid_profile 
		{ 
			profile 			<- "Medio";
			location 			<- any_location_in(one_of(building));
			bussiness_preference<- ["Negocio tradicional"::0.3, "Nuevo negocio"::0.5, "Centro cultural"::0.2];
			transport_preference<- ["Peaton"::0.2, "Auto"::0.4, "MiBici_prob"::0.4];
		}
		
		create person number: number_of_high_profile 
		{ 
			profile 			<- "Alto";
			location 			<- any_location_in(one_of(building));
			bussiness_preference<- ["Negocio tradicional"::0.1, "Nuevo negocio"::0.6, "Centro cultural"::0.3];
			transport_preference<- ["Peaton"::0.1, "Auto"::0.8, "MiBici_prob"::0.1];
		}
		
		
	}
	
	// Reflex para el mapa de calor y la actualización de nivel de trafico en la app
	reflex heat_evolution {
		//ask all cells to decrease their heat level
		cell <- cell * 0.8;
		//diffuse the heat to neighbor cells
		diffuse var: heat on: cell proportion: 0.9;
	
		traffic_level_app <- length(person where (each.transport="Auto" and (each.state="on_route" )))+traffic_base;
	}
	
	// Reflex para gentrificar el vecindario
	
	reflex gentrifica when: gentrificacion = true{
		
	}
	
	
}

// Agentes edificio, estos agentes formaran los lugares de interés en la simulación.
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

// Agentes "camino" que sirven para formar las calles
species road skills: [road_skill]
{
	aspect default
	{
		draw (shape + 5#m) color: #white;
	}
}

// Agentes "intersección" los cuales nos ayudan a formar la ciudad.
species intersection skills: [intersection_skill] ;

// Agentes "MiBici" son los que representan las estaciones de MiBici en la ciudad
species mibici 
{
	aspect default
	{
		pair<float,point> r0 	<-  -90::{1,0,0};	
		draw cube(10) at:location;
		draw logo_mibici size:20 at:location+{0,0,20} rotate: r0;
	}
}


// Agentes persona, estos son los que tomarán la decisión de moverse de un lugar de interés a otro y elejir el medio de transporte de acuerdo
// con sus preferencias.
species person skills: [moving]
{
	string 	profile;
	bool	relocate_active <- true; // 
	map<string,float>	bussiness_preference;
	map<string,float>	transport_preference;
	float traffic_radius <- 250.0;
	int traffic_limit		<- 400;
	bool considering_selling <- false;
	int frustration			<- 0;
	int social_fabric	<- 0;
	float interaction_prob <- 0.0;
	list<person> traffic;
	
	//Target point of the agent
	string			transport;
	point 			target;
	map<int,point> 	route ;
	
	
	//Probability of leaving the building
	float 	leaving_proba <- 0.1;
	//Speed of the agent
	float 	speed <- rnd(10) #km / #h;
	// Random state
	string 	state <- "in_place"; // on_route, in_place, on_route_inter
	int	 	r_step;
	
	
	// Reflejo para decidir salir del lugar actual y elegir otro nuevo
	reflex leave when: (target = nil) and (flip(leaving_proba)) and (state="in_place") {
		string  target_type <- rnd_choice(bussiness_preference);
		
		target 		<-  any_location_in(one_of(building where (each.type=target_type)));
		state <- "leaving";
	}
	
	// Reflejo para seleccionar transporte
	reflex select_transport when: state = "leaving"{
		transport 	<-	rnd_choice(transport_preference);
		
		
		//*********** AQUÍ AGREGA EL CODIGO FALTANTE PARA LA APP  y cambio de decisión***************
		
		//*******************************************************************************************************
		state <- "transport selected";
	}
	
	// Reflejo para iniciar el viaje una vez que se ha seleccionado el medio de transporte
	reflex travel when: state="transport selected" {

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
			match "MiBici_prob"
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
	

	// Reflejo para mover al agente durante su viaje (este es el reflejo principal que mueve al agente de un lado a otro)
	reflex move when: (target != nil and state != "in_place") {
		path path_followed <- goto(target: target, on: road_network, recompute_path: true, return_path: true);

		//Actualiza mapa de calor
		if (path_followed != nil and path_followed.shape != nil and transport="MiBici") {
			cell[path_followed.shape.location] <- cell[path_followed.shape.location] + 20;					
		}

		// Si el agente ha llegado al destino, entonces cambia su estado a "in_place" que significa que está quieto en un edificio
		if (location = target) 
		{	
			if length(route) > 0
			{
				remove key:r_step from: route;
				r_step  <- r_step+1;
				target 	<- route[r_step];
				if (target = nil) {
   					state <- "in_place";
					} 
				else {
   					if (r_step mod 2 = 0 and number_of_bici > 0) {
      					state <- "on_route";
      					number_of_bici <- number_of_bici - 1;
      					transport <- "MiBici";
   						} 
   					else if (r_step mod 2 = 0 and number_of_bici = 0){
   						transport 	<-	rnd_choice(["Peaton"::0.5, "Auto"::0.5]);
   						state <- "transport selected";
   						frustration <- frustration + 1;
   					}
   					else {
      						state <- "on_route_inter";
   					}
				}
				if r_step = 3{
					number_of_bici <- number_of_bici +1;
					transport <- "Peaton";
				}
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


	// Reflejo para recolocar a los agentes que se pierdan a medio camino
	reflex relocate when: current_path = nil and target != nil
	{
		point point_relocate <- any_location_in(one_of(intersection));//(intersection closest_to(self)).location;
		location <- point_relocate;
	}
	
	// Otro reflejo para recolocar al agente
	reflex lost when: current_path = nil and target = nil{
				location 			<- any_location_in(one_of(building));
				state	<- "in_place";
	}

	// Esta acción es una función que se llama durante el reflejo de movimiento y permite que el agente vaya a la
	// velocidad adecuada dependiendo de su medio de transporte
	action change_speed
	{
		if state = "on_route"
		{
			switch(transport)
			{
				match "Auto"
				{
					speed <- rnd(15,40) #km / #h;
				}
				match "MiBici"
				{
					speed <- rnd(5,20) #km / #h;
				}
				match "Peaton"{
					speed <- rnd(6,8) #km / #h;
				}
			}	
		}
		else if state="on_route_inter"
		{
			speed <- rnd(6,8) #km / #h;
		}	
	}
	
	
	
	
	
	// Aspecto del agente en función de su medio de transporte.
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
					draw rectangle(4,6) rotated_by (heading+90) color: #deeppink depth: 2;
				}
				match "MiBici_prob"
				{
					draw rectangle(4,6) rotated_by (heading+90) color: #orange depth: 2;
				}
				
			}}
		else
		{
			draw sphere(3) color: #mediumturquoise;
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
			graphics "Bicis disponibles" background:#black border:#cyan{
				draw "Bicis disponibles" at: {500,1800,10} font:font("Arial", 10, #bold+#italic) color:#white;
				draw string(number_of_bici) at: {500,1900,10} font:font("Arial", 10, #bold+#italic) color:#white;
			}
			
			light #ambient intensity: 128;
			camera 'default' location: {1254.041,2938.6921,1792.4286} target: {1258.8966,1547.6862,0.0};
			species road 	 refresh: true;
			species building refresh: false;
			species mibici 	 refresh: true;
			species person 	 refresh: true;
			species car		 refresh: false;
			
			mesh cell scale: 9 triangulation: true transparency: 0.4 smooth: 3 above: 0.8 color: pal;
		}
		
		
		display "Uso de transporte" type:2d {
			
			chart "Uso de transporte" type:histogram 
			
			style:stack
			x_serie_labels:("cycle"+cycle)
			x_range:5
			{
				data "Peaton" 	value: length(person where (each.transport="Peaton" and (each.state="on_route" or each.state = "on_route_inter")))
					accumulate_values: true						
					color:#mediumturquoise;
				data "Quiere Mibici" 	value: length(person where (each.transport="MiBici_prob"))
					accumulate_values: true						
					color:#orange;	
				data "MiBici" 	value: length(person where (each.transport="MiBici" and (each.state="on_route")))
					accumulate_values: true						
					color:#deeppink;
				data "Auto" 	value: length(person where (each.transport="Auto" and (each.state="on_route" )))
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


