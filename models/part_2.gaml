/**
* Name: GENTRIFICACIÓN Y USO DE TRANSPORTE
* Load graphical scenario 
* Author: Liliana Durán Polanco, Giovana Perez Carrillo & Diego Orozco Castillo
* Tags: 
*/


model gentrif_model_part2

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
	int number_of_high_profile		<- 500;
	
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
	
	
	// Aspecto del agente en función de su medio de transporte.
	aspect default 
	{
		draw sphere(3) color: #mediumturquoise;
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
			species person 	 refresh: true;
			species car		 refresh: false;
			
			mesh cell scale: 9 triangulation: true transparency: 0.4 smooth: 3 above: 0.8 color: pal;
		}
		
		
		
	
	
		
	}
	
	
}


