import QtQml 2.0
import qf.core 1.0
import qf.qmlwidgets 1.0
import Runs 1.0
import "qrc:/qf/core/qml/js/treetable.js" as TreeTable
import "qrc:/qf/core/qml/js/timeext.js" as TimeExt
//import shared.QuickEvent 1.0
import "qrc:/quickevent/core/js/ogtime.js" as OGTime

QtObject {
	//id: root
	property RunsPlugin runsPlugin


	property QfObject internals: QfObject {
		SqlTableModel {
			id: reportModel
		}
	}

	function startListClassesTable(class_filter, insert_vakants)
	{
		var event_plugin = FrameWork.plugin("Event");
		var stage_id = runsPlugin.selectedStageId;
		var tt = new TreeTable.Table();

		reportModel.queryBuilder.clear()
			.select2('classes', 'id, name')
			.select2('classdefs', 'startTimeMin, lastStartTimeMin, startIntervalMin')
			.select2('courses', 'length, climb')
			.from('classes')
			.joinRestricted("classes.id", "classdefs.classId", "classdefs.stageId={{stageId}}")
			.join("classdefs.courseId", "courses.id")
			.orderBy('classes.name');//.limit(1);
		if(class_filter) {
			reportModel.queryBuilder.where(class_filter);
		}
		reportModel.setQueryParameters({stageId: stage_id})
		reportModel.reload();
		tt.setData(reportModel.toTreeTableData());
		tt.setValue("stageId", stage_id)
		tt.setValue("event", event_plugin.eventConfig.value("event"));
		tt.setValue("stageStart", event_plugin.stageStartDateTime(stage_id));

		reportModel.queryBuilder.clear()
			.select2('competitors', 'lastName, firstName, registration, startNumber')
			.select("COALESCE(competitors.lastName, '') || ' ' || COALESCE(competitors.firstName, '') AS competitorName")
			.select2('runs', 'siId, startTimeMs')
			.select2('competitors', 'ranking')
			.select2('competitors', 'licence')
			.from('competitors')
			.joinRestricted("competitors.id", "runs.competitorId", "runs.stageId={{stage_id}} AND runs.isRunning", "INNER JOIN")
			.where("competitors.classId={{class_id}}")
			.orderBy('runs.startTimeMs');
		for(var i=0; i<tt.rowCount(); i++) {
			var class_id = tt.value(i, "classes.id");
			console.debug("class id:", class_id);
			reportModel.setQueryParameters({stage_id: stage_id, class_id: class_id});
			reportModel.reload();
			var ttd = reportModel.toTreeTableData();
			var tt2 = new TreeTable.Table(ttd);
			var start_time_0 = tt.value(i, "startTimeMin") * 60 * 1000;
			var start_time_last = tt.value(i, "lastStartTimeMin") * 60 * 1000;
			var start_interval = tt.value(i, "startIntervalMin") * 60 * 1000;
			if(start_interval > 0 && insert_vakants) {
				for(var j=0; j<tt2.rowCount(); j++) {
					var start_time = tt2.value(j, "startTimeMs");
					//console.info(j, "t0:", start_time_0, start_time_0/60/1000, "start:", start_time, start_time/60/1000)
					while(start_time_0 < start_time) {
						// insert vakant row
						//console.info("adding row:", start_time_0)
						tt2.addRow(j);
						tt2.setValue(j, "startTimeMs", start_time_0);
						tt2.setValue(j, "competitorName", "---");
						tt2.setValue(j, "registration", "");
						tt2.setValue(j, "siId", 0);
						start_time_0 += start_interval;
						j++;
					}
					start_time_0 += start_interval;
				}
				while(start_time_0 <= start_time_last) {
					// insert vakants after
					tt2.addRow();
					tt2.setValue(j, "startTimeMs", start_time_0);
					tt2.setValue(j, "competitorName", "---");
					tt2.setValue(j, "registration", "");
					tt2.setValue(j, "siId", 0);
					start_time_0 += start_interval;
					j++;
				}
			}
			tt.addTable(i, ttd);
		}
		console.debug(tt.toString());
		return tt;
	}

	function startListClubsTable()
	{
		var event_plugin = FrameWork.plugin("Event");
		var stage_id = runsPlugin.selectedStageId;
		var tt = new TreeTable.Table();

		var qs1 = "SELECT COALESCE(substr(registration, 1, 3), '') AS clubAbbr FROM competitors GROUP BY clubAbbr ORDER BY clubAbbr";
		reportModel.query = "SELECT t2.clubAbbr, clubs.name FROM ( " + qs1 + " ) AS t2"
				+ " LEFT JOIN clubs ON t2.clubAbbr=clubs.abbr"
				+ " ORDER BY t2.clubAbbr";
		reportModel.reload();
		tt.setData(reportModel.toTreeTableData());
		tt.setValue("stageId", stage_id)
		tt.setValue("event", event_plugin.eventConfig.value("event"));
		tt.setValue("stageStart", event_plugin.stageStartDateTime(stage_id));
		tt.column(0).type = "QString"; // sqlite returns clubAbbr column as QVariant::Invalid, set correct type
		//console.info(tt.toString());

		reportModel.queryBuilder.clear()
			.select2('competitors', 'registration, startNumber')
			.select("COALESCE(competitors.lastName, '') || ' ' || COALESCE(competitors.firstName, '') AS competitorName")
			.select("lentcards.siid IS NOT NULL OR runs.cardLent AS cardLent")
			.select2('classes', 'name')
			.select2('runs', 'siId, startTimeMs')
			.from('competitors')
			.joinRestricted("competitors.id", "runs.competitorId", "runs.stageId={{stage_id}} AND runs.isRunning", "INNER JOIN")
			.joinRestricted("runs.siid", "lentcards.siid", "NOT lentcards.ignored")
			.join("competitors.classId", "classes.id")
			.where("COALESCE(substr(competitors.registration, 1, 3), '')='{{club_abbr}}'")
			.orderBy('classes.name, runs.startTimeMs');
		for(var i=0; i<tt.rowCount(); i++) {
			var club_abbr = tt.value(i, "clubAbbr");
			console.debug("club_abbr:", club_abbr);
			reportModel.setQueryParameters({club_abbr: club_abbr, stage_id: stage_id});
			reportModel.reload();
			//console.info(reportModel.effectiveQuery());
			var ttd = reportModel.toTreeTableData();
			tt.addTable(i, ttd);
		}
		return tt;
	}

	function startListStartersTable(class_filter)
	{
		var event_plugin = FrameWork.plugin("Event");
		var stage_id = runsPlugin.selectedStageId;
		//var stage_data = event_plugin.stageDataMap(stage_id);
		var tt = new TreeTable.Table();

		reportModel.queryBuilder.clear()
			.select2('competitors', 'registration, id')
			.select("COALESCE(competitors.lastName, '') || ' ' || COALESCE(competitors.firstName, '') AS competitorName")
			.select("COALESCE(runs.startTimeMs / 1000 / 60, 0) AS startTimeMin")
			.select2('runs', 'siId, startTimeMs')
			.select2('classes', 'name')
			.from('competitors')
			.joinRestricted("competitors.id", "runs.competitorId", "runs.stageId={{stageId}} AND runs.isRunning", "INNER JOIN")
			.join("competitors.classId", "classes.id")
			.orderBy('runs.startTimeMs, classes.name, competitors.lastName')//.limit(50);
		if(class_filter) {
			reportModel.queryBuilder.where(class_filter)
		}
		reportModel.setQueryParameters({stageId: stage_id})
		reportModel.reload();
		//console.info(reportModel.effectiveQuery());
		tt.setData(reportModel.toTreeTableData());
		tt.setValue("stageId", stage_id)
		tt.setValue("event", event_plugin.eventConfig.value("event"));
		return tt;
	}

	function nStagesClassesTable(stages_count)
	{
		var event_plugin = FrameWork.plugin("Event");

		var tt = new TreeTable.Table();
		reportModel.queryBuilder.clear()
			.select2('classes', 'id, name')
			.from('classes')
			.orderBy('classes.name');//.limit(1);
		reportModel.reload();
		tt.setData(reportModel.toTreeTableData());
		tt.setValue("stagesCount", stages_count)
		tt.setValue("event", event_plugin.eventConfig.value("event"));

		for(var i=0; i<tt.rowCount(); i++) {
			var class_id = tt.value(i, "classes.id");
			console.debug("class id:", class_id);
			reportModel.queryBuilder.clear()
				.select2('competitors', 'registration, lastName, firstName, siId')
				.select("COALESCE(competitors.lastName, '') || ' ' || COALESCE(competitors.firstName, '') AS competitorName")
				.from('competitors')
				.where("competitors.classId={{class_id}}")
				.orderBy("competitors.lastName, competitors.registration");
			for(var stage_id = 1; stage_id <= stages_count; stage_id++) {
				var runs_table = "runs" + stage_id;
				reportModel.queryBuilder
					.select2(runs_table, "siid, startTimeMs")
					.joinRestricted("competitors.id", "runs.competitorId AS " + runs_table, runs_table + ".stageId=" + stage_id + " AND " + runs_table + ".isRunning")
			}
			reportModel.setQueryParameters({class_id: class_id});
			reportModel.reload();
			var ttd = reportModel.toTreeTableData();
			var tt2 = new TreeTable.Table(ttd);
			tt.addTable(i, ttd);
		}
		//console.info(tt.toString());
		return tt;
	}

	function nStagesClubsTable(stages_count)
	{
		var event_plugin = FrameWork.plugin("Event");

		var tt = new TreeTable.Table();
		var qs1 = "SELECT * FROM ( SELECT substr(registration, 1, 3) AS clubAbbr FROM competitors) AS t GROUP BY clubAbbr ORDER BY clubAbbr";
		reportModel.query = "SELECT t2.clubAbbr, clubs.name FROM ( " + qs1 + " ) AS t2"
				+ " LEFT JOIN clubs ON t2.clubAbbr=clubs.abbr"
				+ " ORDER BY t2.clubAbbr";// + " LIMIT 1";
		reportModel.reload();
		tt.setData(reportModel.toTreeTableData());
		tt.setValue("stagesCount", stages_count)
		tt.setValue("event", event_plugin.eventConfig.value("event"));

		for(var i=0; i<tt.rowCount(); i++) {
			var club_abbr = tt.value(i, "clubAbbr");
			//console.debug("class id:", class_id);
			reportModel.queryBuilder.clear()
				.select2('competitors', 'registration, siId')
				.select("COALESCE(competitors.lastName, '') || ' ' || COALESCE(competitors.firstName, '') AS competitorName")
				.select2('classes', 'name')
				.from('competitors')
				.join("competitors.classId", "classes.id")
				.where("substr(competitors.registration, 1, 3)='{{club_abbr}}'")
				.orderBy('classes.name, competitors.lastName');
			for(var stage_id = 1; stage_id <= stages_count; stage_id++) {
				var runs_table = "runs" + stage_id;
				reportModel.queryBuilder
					.select2(runs_table, "siid, startTimeMs")
					.joinRestricted("competitors.id", "runs.competitorId AS " + runs_table, runs_table + ".stageId=" + stage_id + " AND " + runs_table + ".isRunning")
			}
			reportModel.setQueryParameters({club_abbr: club_abbr});
			reportModel.reload();
			var ttd = reportModel.toTreeTableData();
			var tt2 = new TreeTable.Table(ttd);
			tt.addTable(i, ttd);
		}
		console.debug(tt.toString());
		return tt;
	}

	function printStartListClasses()
	{
		Log.info("runs printResultsCurrentStage triggered");
		var dlg = runsPlugin.createReportOptionsDialog(FrameWork);
		dlg.persistentSettingsId = "startListClassesReportOptions";
		dlg.startListOptionsVisible = true;
		//dlg.dialogType = RunsPlugin.StartListReport;
		//var mask = InputDialogSingleton.getText(this, qsTr("Get text"), qsTr("Class mask (use wild cards [*?]):"), "*");
		if(dlg.exec()) {
			var tt = startListClassesTable(dlg.sqlWhereExpression(), dlg.isStartListPrintVacants());
			var opts = dlg.optionsMap();
			QmlWidgetsSingleton.showReport(runsPlugin.manifest.homeDir + "/reports/startList_classes.qml"
										   , tt.data()
										   , qsTr("Start list by clases")
										   , "printStartList"
										   , {isBreakAfterEachClass: dlg.isBreakAfterEachClass()
											   , isColumnBreak: dlg.isColumnBreak()
											   , isPrintStartNumbers: dlg.isStartListPrintStartNumbers()
											   , options: opts
										     }
										   );
		}
		dlg.destroy();
	}

	function printStartListClubs()
	{
		Log.info("runs printStartListClubs triggered");
		var dlg = runsPlugin.createReportOptionsDialog(FrameWork);
		dlg.persistentSettingsId = "startListClubsReportOptions";
		dlg.classFilterVisible = false;
		//dlg.startListOptionsVisible = true;
		if(dlg.exec()) {
			var tt = startListClubsTable();
			var opts = dlg.optionsMap();
			QmlWidgetsSingleton.showReport(runsPlugin.manifest.homeDir + "/reports/startList_clubs.qml"
										   , tt.data()
										   , qsTr("Start list by clubs")
										   , "printStartList"
										   , {isBreakAfterEachClass: dlg.isBreakAfterEachClass()
											   , isColumnBreak: dlg.isColumnBreak()
											   , isPrintStartNumbers: dlg.isStartListPrintStartNumbers()
											   , options: opts
										     }
										   );
		}
		dlg.destroy();
	}

	function printStartListStarters()
	{
		Log.info("runs printStartListStarters triggered");
		var dlg = runsPlugin.createReportOptionsDialog(FrameWork);
		dlg.persistentSettingsId = "startListStartersReportOptions";
		dlg.classFilterVisible = true;
		dlg.startersOptionsVisible = true;
		if(dlg.exec()) {
			var tt = startListStartersTable(dlg.sqlWhereExpression());
			var opts = dlg.optionsMap();
			QmlWidgetsSingleton.showReport(runsPlugin.manifest.homeDir + "/reports/startList_starters.qml"
										   , tt.data()
										   , qsTr("Start list for starters")
										   , "printStartList"
										   , { isPrintStartNumbers: dlg.isStartListPrintStartNumbers()
											   , lineSpacing: opts.startersOptionsLineSpacing
											   , options: opts
										     }
										   );
		}
		dlg.destroy();
	}

	function printClassesNStages()
	{
		Log.info("runs startLists printClassesNStages triggered");
		var event_plugin = FrameWork.plugin("Event");
		var stage_id = event_plugin.currentStageId;
		var n = InputDialogSingleton.getInt(this, qsTr("Get number"), qsTr("Number of stages:"), stage_id, 1, event_plugin.stageCount);
		var tt = nStagesClassesTable(n);
		//console.info("n:", n)
		QmlWidgetsSingleton.showReport(runsPlugin.manifest.homeDir + "/reports/startLists_classes_nstages.qml"
									   , tt.data()
									   , qsTr("Start list by clases")
									   , ""
									   , {stageCount: n});
	}

	function printClubsNStages()
	{
		Log.info("runs startLists printClubsNStages triggered");
		var event_plugin = FrameWork.plugin("Event");
		var stage_id = event_plugin.currentStageId;
		var n = InputDialogSingleton.getInt(this, qsTr("Get number"), qsTr("Number of stages:"), stage_id, 1, event_plugin.stageCount);
		var tt = nStagesClubsTable(n);
		//console.info("n:", n)
		QmlWidgetsSingleton.showReport(runsPlugin.manifest.homeDir + "/reports/startLists_clubs_nstages.qml"
									   , tt.data()
									   , qsTr("Start list by clubs")
									   , ""
									   , {stageCount: n});
	}

	function exportHtmlStartListClasses()
	{
		var default_file_name = "startlist-classes.html";

		var tt1 = startListClassesTable("", false);
		var body = ['body']
		var h1_str = "{{documentTitle}}";
		var event = tt1.value("event");
		if(event.stageCount > 1)
			h1_str = "E" + tt1.value("stageId") + " " + h1_str;
		body.push(['h1', h1_str]);
		body.push(['h2', event.name]);
		body.push(['h3', event.place]);
		body.push(['h3', tt1.value("stageStart")]);
		var div1 = ['div'];
		body.push(div1);
		for(var i=0; i<tt1.rowCount(); i++) {
			div1.push(['a', {"href": "#class_" + tt1.value(i, 'classes.name')}, tt1.value(i, 'classes.name')], "&nbsp;")
		}
		for(var i=0; i<tt1.rowCount(); i++) {
			div1 = ['h2', ['a', {"name": "class_" + tt1.value(i, 'classes.name')}, tt1.value(i, 'classes.name')]];
			body.push(div1);
			div1 = ['h3', qsTr("length:"), tt1.value(i, 'courses.length'), ' ', qsTr("climb:"), tt1.value(i, 'courses.climb')];
			body.push(div1);
			var table = ['table'];
			body.push(table);
			var tt2 = tt1.table(i);
			var tr = ['tr',
					  ['th', qsTr("Start")],
					  ['th', qsTr("Name")],
					  ['th', qsTr("Registration")],
					  ['th', qsTr("Rank")],
					  ['th', qsTr("Lic")],
					  ['th', qsTr("SI")]
					];
			table.push(tr);
			for(var j=0; j<tt2.rowCount(); j++) {
				tr = ['tr'];
				if(j % 2)
					tr.push({"class": "odd"});
				tr.push(['td', OGTime.msecToString_mmss(tt2.value(j, 'startTimeMs'))]);
				tr.push(['td', tt2.value(j, 'competitorName')]);
				tr.push(['td', tt2.value(j, 'registration')]);
				tr.push(['td', tt2.value(j, 'ranking')]);
				tr.push(['td', tt2.value(j, 'licence')]);
				tr.push(['td', tt2.value(j, 'runs.siId')]);
				table.push(tr);
			}
		}
		var file_name = File.tempPath() + "/quickevent/e" + tt1.value("stageId");
		if(File.mkpath(file_name)) {
			file_name += "/" + default_file_name;
			File.writeHtml(file_name, body, {documentTitle: qsTr("Start list by classes")});
			Log.info("exported:", file_name);
			return file_name;
		}
		return "";
	}

	function exportStartListIofXml3(file_path)
	{
		var event_plugin = FrameWork.plugin("Event");
		var start00_datetime = event_plugin.stageStartDateTime(runsPlugin.selectedStageId);
		//console.info("start00_datetime:", start00_datetime, typeof start00_datetime)
		var start00_epoch_sec = start00_datetime.getTime();
		var print_vacants = !(event_plugin.eventConfig.stageCount === runsPlugin.selectedStageId && event_plugin.eventConfig.isHandicap);
		console.debug("print_vacants", print_vacants);
		var tt1 = startListClassesTable("", print_vacants);

		var xml_root = ['StartList' ,
						{ "xmlns": "http://www.orienteering.org/datastandard/3.0",
							"xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance",
							"iofVersion": "3.0" , "creator": "QuickEvent",
							"createTime": TimeExt.dateTimeToUTCISOString(new Date())
						}];

		var event = tt1.value("event");
		var xml_event = ['Event'];
		xml_root.push(xml_event);
		xml_event.push(['Name', event.name]);
		xml_event.push(['StartTime', ['Date', TimeExt.dateToUTCISOString(event.date)], ['Time', TimeExt.timeToUTCISOString(event.date)]]);
		xml_event.push(['EndTime', ['Date', TimeExt.dateToUTCISOString(event.date)], ['Time', TimeExt.timeToUTCISOString(event.date)]]);
		var director = (event.director + '').split(' ');
		var main_referee = (event.mainReferee + '').split(' ');
		xml_event.push(['Official', {"type": "Director"}, ['Person', ['Name', ['Family', director[0]], ['Given', director[1]]]]]);
		xml_event.push(['Official', {"type": "MainReferee"}, ['Person', ['Name', ['Family', main_referee[0]], ['Given', main_referee[1]]]]]);

		for(var i=0; i<tt1.rowCount(); i++) {
			var class_start = ['ClassStart'];
			xml_root.push(class_start);
			class_start.push(['Class', ["Id", tt1.value(i, "classes.id")], ["Name", tt1.value(i, "classes.name")]]);
			class_start.push(['Course', ["Length", tt1.value(i, "courses.length")], ["Climb", tt1.value(i, "courses.climb")]]);
			class_start.push(['StartName', "Start1"]);
			var tt2 = tt1.table(i);
			var pos = 0;
			for(var j=0; j<tt2.rowCount(); j++) {
				pos++;
				var xml_person = ['PersonStart'];
				class_start.push(xml_person);
				var person = ['Person'];
				xml_person.push(person);
				person.push(['Id', tt2.value(j, "competitors.registration")]);
				var family = tt2.value(j, "competitors.lastName");
				var given = tt2.value(j, "competitors.firstName");
				person.push(['Name', ['Family', family], ['Given', given]]);
				var xml_start = ['Start'];
				xml_person.push(xml_start);
				var stime_msec = tt2.value(j, "startTimeMs");
				//console.info(start00_datetime.toJSON(), start00_datetime.getHours(), start00_epoch_sec / 60 / 60);
				//console.info(family, given, start00_epoch_sec, stime_sec, stime_sec / 60);
				var stime_datetime = new Date(start00_epoch_sec + stime_msec);
				//sdatetime.setTime(start00_epoch_sec);
				//console.warn(stime_datetime.toJSON());
				//stime_epoch_sec = start00_epoch_sec + stime_epoch_sec;
				xml_start.push(['StartTime', TimeExt.dateTimeToUTCISOString(stime_datetime)])
				xml_start.push(['ControlCard', tt2.value(j, "runs.siId")])
			}
		}

		File.writeXml(file_path, xml_root, {documentTitle: qsTr("E%1 IOF XML stage results").arg(tt1.value("stageId"))});
		Log.info("exported:", file_path);
	}


	//export start list Emma
	function exportStartListEmma(file_name)
	{
		var str = "";
		var tt1 = startListStartersTable("");
		for(var i=0; i<tt1.rowCount(); i++) {
			//ID
			var part = tt1.value(i, 'competitors.id');
			part += " ".repeat(5 - part.toString().length);
			str += part + " ";
			//SI number
			part = tt1.value(i, 'runs.siId');
			part = " ".repeat(8 - part.toString().length) + part;
			str += part + " ";
			//class name
			part = tt1.value(i, 'classes.name');
			part += " ".repeat(7 - part.length);
			str += part + " ";
			//registration
			part = tt1.value(i, 'registration');
			part += " ".repeat(7 - part.length);
			str += part + " ";
			//competitor name
			part = tt1.value(i, 'competitorName').substring(0,21);
			part += " ".repeat(22 - part.toString().length);
			str += part + " ";
			//start time
			//TODO zmenit na format mmm.ss,zzzz
			var msec = tt1.value(i, 'startTimeMs');
			var min = (msec / 60000) >> 0
			if(min < 10)
				str += '00'
			else if(min < 100)
				str += '0'
			str += min;
			str += '.'
			var sec = (msec % 60000 / 1000) >> 0
			if(sec < 10)
				str += '0'
			str += sec;
			str += ','
			var zzzz = msec % 1000 * 10
			if(zzzz < 10)
				str += '000'
			else if(zzzz < 100)
				str += '00'
			else if(zzzz < 1000)
				str += '000'
			str += zzzz;
			str += "\n";
		}
		/// TODO, export in CP1250
		if(File.write(file_name, str)) {
			Log.info("exported:", file_name);
			return file_name;
		}

		return "";
	}
	//end export start list Emma

	function exportHtmlStartListClubs()
	{
		var default_file_name = "startlist-clubs.html";

		var tt1 = startListClubsTable();
		var body = ['body']
		var h1_str = "{{documentTitle}}";
		var event = tt1.value("event");
		if(event.stageCount > 1)
			h1_str = "E" + tt1.value("stageId") + " " + h1_str;
		body.push(['h1', h1_str]);
		body.push(['h2', event.name]);
		body.push(['h3', event.place]);
		body.push(['h3', tt1.value("stageStart")]);
		var div1 = ['div'];
		body.push(div1);
		for(var i=0; i<tt1.rowCount(); i++) {
			div1.push(['a', {"href": "#club_" + tt1.value(i, 'clubAbbr')}, tt1.value(i, 'clubAbbr')], "&nbsp;")
		}
		for(var i=0; i<tt1.rowCount(); i++) {
			div1 = ['h2', ['a', {"name": "club_" + tt1.value(i, 'clubAbbr')}, tt1.value(i, 'clubAbbr')]];
			body.push(div1);
			div1 = ['h3', tt1.value(i, 'name')];
			body.push(div1);
			var table = ['table'];
			body.push(table);
			var tt2 = tt1.table(i);
			var tr = ['tr',
					  ['th', qsTr("Start")],
					  ['th', qsTr("Class")],
					  ['th', qsTr("Name")],
					  ['th', qsTr("Registration")],
					  ['th', qsTr("SI")]
					];
			table.push(tr);
			for(var j=0; j<tt2.rowCount(); j++) {
				tr = ['tr'];
				if(j % 2)
					tr.push({"class": "odd"});
				tr.push(['td', OGTime.msecToString_mmss(tt2.value(j, 'startTimeMs'))]);
				tr.push(['td', tt2.value(j, 'classes.name')]);
				tr.push(['td', tt2.value(j, 'competitorName')]);
				tr.push(['td', tt2.value(j, 'registration')]);
				tr.push(['td', tt2.value(j, 'runs.siId')]);
				table.push(tr);
			}
		}
		//var s = JSON.stringify(html, null, 2);
		var file_name = File.tempPath() + "/quickevent/e" + tt1.value("stageId");
		if(File.mkpath(file_name)) {
			file_name += "/" + default_file_name;
			File.writeHtml(file_name, body, {documentTitle: qsTr("Start list by clubs")});
			Log.info("exported:", file_name);
			return file_name;
		}
		return "";
	}

}
