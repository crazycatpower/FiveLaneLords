extends "res://road_toll_story.gd"

func begin(g, won: bool = false) -> void:
	victory = won
	step = 0
	heading = "1-3 · 故鄉木橋"
	opening_caption = "糧車還沒走遠，橋頭已經封了。"
	victory_caption = "糧食換來的鐵器，究竟交給了誰？"
	next_caption = "追查名冊"
	if won:
		lines = [
			["村民","車攔下來了！這些箱子裡全是刀和箭頭，哪有什麼農具！","mob","lord"],
			["領主","拿百姓的口糧換兵器。你們要打誰？","lord","guard"],
			["俘虜","我只負責押車！收貨的人不報名字，拿著這本名冊就能領貨。","guard","lord"],
			["村民","等等，這裡寫著我爹的名字……他去年就死了。\n還有隔壁老吳，名字寫錯了，可他也早不在了！","mob","lord"],
		]
		if g.adventure.recruit == "bandit":
			lines.append(["強盜","這些人我認得。被趕出村子的，也都寫在這上頭。\n大人，這不是送貨的名冊。","bandit","lord"])
		elif g.adventure.recruit == "knight":
			lines.append(["騎士","這是軍中點名用的格式。可這些名字……根本不是士兵。","knight","lord"])
		lines.append(["領主","帶上名冊，留下俘虜作證。\n下一站，去找收貨的人。我要知道，誰在替死人領兵器。","lord","guard"])
	else:
		lines = [
			["村民","就是那輛車！我們的糧才卸下來，他們就把鐵箱裝上去了！","mob","lord"],
			["守橋軍","關上路障！車隊先走，其餘人守住橋頭！","guard","lord"],
			["領主","留下車和押糧的人。否則，我們自己過去拿。","lord","guard"],
			["守橋軍","就憑這群拿草叉的？弓手，上箭樓！","guard","lord"],
		]
		if g.adventure.recruit == "bandit":
			lines.append_array([
				["強盜","車尾那道白漆，我認得！每回收走糧食的都是他們！","bandit","lord"],
				["領主","盯住車，別只顧著報仇。我要留下活口。","lord","bandit"],
			])
		elif g.adventure.recruit == "knight":
			lines.append_array([
				["騎士","箱上的烙印是東境軍械庫的。這不是私下買賣，有人在調兵。","knight","lord"],
				["領主","那就把箱子和人一起留下。這回別再讓他們拿命令搪塞。","lord","knight"],
			])
		lines.append_array([
			["村民","撞槌推來了！這根木頭還是我爹當年修橋剩下的！","mob","lord"],
			["領主","盾兵先上，護住撞槌！打穿防線，把車隊截下來！","lord","mob"],
			["突破橋頭","攻城槌已在牌組中。先派部隊掩護，再讓攻城槌接近敵方建築。\n五條路皆可進攻；攻入任一路敵方底線即可獲勝。","lord","guard"],
		])
	show(g)
