/*************************************************************************
#
# Investigative Case File System
#
# Copyright 2019 by Graham A. Field
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 3.
#
# This program is distributed WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
**************************************************************************/

  ///////////////////////////////////////////////
  // Enable or disable a hidden div
  function enaDiv(idDiv, idInp) {
    var div = document.getElementById(idDiv);
    var ena = document.getElementById(idInp);
    if( ena.getAttribute("value") == "true" ) {
      div.classList.add("hidden");
      ena.setAttribute("value", "false");
    } else {
      div.classList.remove("hidden");
      ena.setAttribute("value", "true");
    }
  }


  ///////////////////////////////////////////////
  // Delete parent div
  function delDiv(btn) {
    var div = btn.parentNode;
    div.parentNode.removeChild(div);
  }


  ///////////////////////////////////////////////
  // Create a delete button
  function btnDelDiv(btn_class, btn_text){
    var btn = document.createElement("button");
    btn.setAttribute("class", btn_class);
    btn.setAttribute("type", "button");
    btn.setAttribute("onclick", "delDiv(this)");
    btn.appendChild(document.createTextNode(btn_text));
    return btn;
  }


  ///////////////////////////////////////////////
  // Add an input to a list
  function addListInput(list_id, input_class, button){
    var list = document.getElementById(list_id);

    var cnt_inp = list.getElementsByTagName("input")[0];
    var cnt = cnt_inp.getAttribute("value");
    cnt = parseInt(cnt, 10) + 1
    cnt_inp.setAttribute("value", cnt);

    var base = cnt_inp.getAttribute("name");

    var div = document.createElement("div");
    list.appendChild(div);

    var inp = document.createElement("input");
    inp.setAttribute("type", "text");
    inp.setAttribute("class", input_class);
    inp.setAttribute("name", base + "-" + cnt);
    div.appendChild(inp);

    if( button ){
      var btn = btnDelDiv(button, "X");
      div.appendChild(btn);
    }

    inp.focus();
  }


  ///////////////////////////////////////////////
  // Add a tag
  function addTag(id) {
    addListInput(id, "form-tag", "form-del");
  }


  ///////////////////////////////////////////////
  // Add a stat to a case
  function cseAddStat() {
    addListInput("cse-stat-list", "form-stat", "form-del");
  }



 // Case

    function cseAddAcc(){
      var acnt = document.getElementById("cse-acc-cnt");
      var acc_cnt = acnt.getAttribute("value");
      acc_cnt = parseInt(acc_cnt, 10) + 1;
      acnt.setAttribute("value", acc_cnt);

      var alist = document.getElementById("cse-acc-list");

      var row = document.createElement("div");
      row.setAttribute("class", "list-row");
      alist.appendChild(row);

      var inp = document.createElement("input");
      inp.setAttribute("type", "hidden");
      inp.setAttribute("name", "cse-acc-" + acc_cnt);
      inp.setAttribute("value", "1");
      row.appendChild(inp);

      inp = document.createElement("input");
      inp.setAttribute("type", "text");
      inp.setAttribute("class", "form-perm");
      inp.setAttribute("name", "cse-acc-" + acc_cnt + "-perm");
      row.appendChild(inp);
      inp.focus();

      var glst = document.createElement("div");
      row.appendChild(glst);
      row.appendChild(document.createTextNode(" "));

      var gnt = document.createElement("div");
      glst.appendChild(gnt);

      inp = document.createElement("input");
      inp.setAttribute("type", "text");
      inp.setAttribute("class", "form-usergrp");
      inp.setAttribute("name", "cse-acc-" + acc_cnt + "-1");
      glst.appendChild(inp);

      inp = document.createElement("button");
      inp.setAttribute("type", "button");
      inp.setAttribute("class", "add-grant");
      inp.setAttribute("onclick", "cseAddGrant(this)");
      inp.appendChild(document.createTextNode("+"));
      row.appendChild(inp);
    }

    function cseAddGrant(b){
      var row = b.parentNode;
      var cnt = row.getElementsByTagName("input")[0];
      var glst = row.getElementsByTagName("div")[0];
      var name = cnt.getAttribute("name");

      var gcnt = cnt.getAttribute("value");
      gcnt = parseInt(gcnt, 10) + 1;
      cnt.setAttribute("value", gcnt);

      var div = document.createElement("div");
      glst.appendChild(div);

      var inp = document.createElement("input");
      inp.setAttribute("type", "text");
      inp.setAttribute("class", "form-usergrp");
      inp.setAttribute("name", name + "-" + gcnt);
      div.appendChild(inp);
      inp.focus();
    }


// Entry

    function entAddIndex(){
      var ht = new XMLHttpRequest();
      ht.onreadystatechange = function() {
        if( this.readyState == 4 && this.status == 200) {
          var jr = JSON.parse(ht.responseText);
          if( jr.index != null ){
            entAddIndexRaw(jr.index, jr.title);
          }
        }
      };

      var scr = document.getElementById("ent-idx-script");
      scr = scr.getAttribute("value");

      var cid = document.getElementById("ent-idx-caseid");
      cid = cid.getAttribute("value");

      var tit = document.getElementById("ent-idx-lu");
      tit = encodeURIComponent(tit.value);
      var url = scr + "/index_lookup?title=" + tit + "&caseid=" + cid;

      ht.open("GET", url, true);
      ht.send();
    }

    function entAddIndexRaw(num, title){
      var icnt = document.getElementById("ent-idx-cnt");
      var idx_cnt = icnt.getAttribute("value");
      idx_cnt = parseInt(idx_cnt, 10) + 1;
      icnt.setAttribute("value", idx_cnt);

      var lst = document.getElementById("ent-idx-list");

      var div = document.createElement("div");
      lst.appendChild(div);

      var inp = document.createElement("input");
      inp.setAttribute("type", "hidden");
      inp.setAttribute("name", "ent-idx-" + idx_cnt);
      inp.setAttribute("value", num);
      div.appendChild(inp);

      div.appendChild(document.createTextNode(title));

      var btn = btnDelDiv("form-del", "X");
      div.appendChild(btn);
    }


    function entAddStat(){
      var scnt = document.getElementById("ent-stats-cnt");
      var stat_cnt = scnt.getAttribute("value");
      stat_cnt = parseInt(stat_cnt, 10) + 1;
      scnt.setAttribute("value", stat_cnt);

      var sel = document.getElementById("ent-stat-sel");
      var stat = sel.value;

      var slist = document.getElementById("ent-stats-list");

      var row = document.createElement("div");
      row.setAttribute("class", "list-row");
      slist.appendChild(row);

      var inp = document.createElement("input");
      inp.setAttribute("type", "hidden");
      inp.setAttribute("name", "ent-stat-" + stat_cnt);
      inp.setAttribute("value", "1");
      row.appendChild(inp);

      inp = document.createElement("input");
      inp.setAttribute("type", "hidden");
      inp.setAttribute("name", "ent-stat-" + stat_cnt + "-name");
      inp.setAttribute("value", stat);
      row.appendChild(inp);

      var div = document.createElement("div");
      div.setAttribute("class", "list-stat");
      div.appendChild(document.createTextNode(stat));
      row.appendChild(div);

      inp = document.createElement("input");
      inp.setAttribute("type", "text");
      inp.setAttribute("class", "form-float");
      inp.setAttribute("name", "ent-stat-" + stat_cnt + "-value");
      row.appendChild(inp);
      row.appendChild(document.createTextNode(" "));
      inp.focus();

      clst = document.createElement("div");
      clst.setAttribute("class", "list-vert");
      row.appendChild(clst);
      row.appendChild(document.createTextNode(" "));

      div = document.createElement("div");
      clst.appendChild(div);

      inp = document.createElement("input");
      inp.setAttribute("type", "text");
      inp.setAttribute("class", "form-usergrp");
      inp.setAttribute("name", "ent-stat-" + stat_cnt + "-1");
      clst.appendChild(inp);

      inp = document.createElement("button");
      inp.setAttribute("type", "button");
      inp.setAttribute("class", "add-claim");
      inp.setAttribute("onClick", "entAddClaim(this)");
      inp.appendChild(document.createTextNode("+"));
      row.appendChild(inp);
    }


    function entAddClaim(b){
      var row = b.parentNode;
      var cnt = row.getElementsByTagName("input")[0];
      var clst = row.getElementsByTagName("div")[1];
      var name = cnt.getAttribute("name");

      var ccnt = cnt.getAttribute("value");
      ccnt = parseInt(ccnt, 10) + 1;
      cnt.setAttribute("value", ccnt);

      var div = document.createElement("div");
      clst.appendChild(div);

      var inp = document.createElement("input");
      inp.setAttribute("type", "text");
      inp.setAttribute("class", "form-usergrp");
      inp.setAttribute("name", name + "_" + ccnt);
      div.appendChild(inp);
      inp.focus();
    }


    function entAddPerm(){
      var pcnt = document.getElementById("ent-perm-cnt");
      var perm_cnt = pcnt.getAttribute("value");
      perm_cnt = parseInt(perm_cnt, 10);
      perm_cnt = perm_cnt + 1;
      pcnt.setAttribute("value", perm_cnt);

      var sel = document.getElementById("ent-perm-sel");
      var perm = sel.value;

      var div = document.createElement("div");

      var txt = document.createTextNode(perm);
      div.appendChild(txt);

      var inp = document.createElement("input");
      inp.setAttribute("type", "hidden");
      inp.setAttribute("name", "ent-perm-" + perm_cnt);
      inp.setAttribute("value", perm);
      div.appendChild(inp);

      var btn = btnDelDiv("form-del", "X");
      document.createElement("button");
      div.appendChild(btn);

      var lst = document.getElementById("ent-perm-list");
      lst.appendChild(div);
    }


    function entAddFile(){
      var fcnt = document.getElementById("ent-file-cnt");
      var file_cnt = fcnt.getAttribute("value");
      file_cnt = parseInt(file_cnt, 10);
      file_cnt = file_cnt + 1;

      var div = document.createElement("div");

      var inp = document.createElement("input");
      inp.setAttribute("type", "text");
      inp.setAttribute("name", "ent-file-" + file_cnt + "-name");
      inp.setAttribute("class", "form-file-name");
      div.appendChild(inp);

      inp = document.createElement("input");
      inp.setAttribute("type", "file");
      inp.setAttribute("name", "ent-file-" + file_cnt + "-file");
      inp.setAttribute("class", "form-file-upl");
      div.appendChild(inp);

      inp = btnDelDiv("form-del", "X");
      div.appendChild(inp);

      var lst = document.getElementById("ent-file-list");
      lst.appendChild(div);

      fcnt.setAttribute("value", file_cnt);
    }


// Action

    function actEnable(){
      var but = document.getElementById("act-task-add");
      var ena = document.getElementById("act-ena");
      var tsk = document.getElementById("act-tasks");

      var enabled = ena.getAttribute("value");
      if( enabled == "true" ){
        ena.setAttribute("value", "false");
        tsk.setAttribute("class", "sect-right hidden");
        but.setAttribute("class", "sect-right invisible");
      } else {
        ena.setAttribute("value", "true");
        tsk.setAttribute("class", "sect-right");
        but.setAttribute("class", "sect-right");
      }
    }

    function actRow(label, tsk){
      var row = document.createElement("div");
      row.setAttribute("class", "form-row");
      var div = document.createElement("div");
      div.setAttribute("class", "list-label");
      div.appendChild(document.createTextNode(label));
      row.appendChild(div);
      tsk.appendChild(row);
      return row;
    }

    function actText(name, cl, row){
      var inp = document.createElement("input");
      inp.setAttribute("type", "text");
      inp.setAttribute("name", name);
      inp.setAttribute("class", cl);
      row.appendChild(inp);
      return inp;
    }

    function actCheck(name, cl, row){
      inp = document.createElement("input");
      inp.setAttribute("type", "checkbox");
      inp.setAttribute("name", name);
      inp.setAttribute("class", cl);
      inp.setAttribute("value", "true");
      inp.setAttribute("checked", "");
      row.appendChild(inp);
      return inp;
    }

    function actAddTask(){
      var tasks = document.getElementById("act-tasks");
      var acnt = document.getElementById("act-cnt");

      var tnum = acnt.getAttribute("value");
      tnum = parseInt(tnum, 10) + 1;
      acnt.setAttribute("value", tnum);

      var tsk = document.createElement("div");
      tsk.setAttribute("class", "task");
      tasks.appendChild(tsk);

      var row = actRow("Tasked:", tsk);
      var inp_tsk = actText("act-" + tnum + "-task", "usergrp", row);

      row = actRow("Title:", tsk);
      actText("act-" + tnum + "-title", "form-title", row);

      row = actRow("Open:", tsk);
      actCheck("act-" + tnum + "-status", "form-check", row);

      row = actRow("Flag:", tsk);
      actCheck("act-" + tnum + "-flag", "form-check", row);

      row = actRow("Time:", tsk);
      actText("act-" + tnum + "-time", "form-time", row);

      row = actRow("Tags:", tsk);
      var tags = document.createElement("div");
      tags.setAttribute("class", "tags-list");
      tags.setAttribute("id", "act-" + tnum + "-tag-list");
      row.appendChild(tags);
      var inp = document.createElement("input");
      inp.setAttribute("type", "hidden");
      inp.setAttribute("name", "act-" + tnum + "-tag");
      inp.setAttribute("value", "0");
      tags.appendChild(inp);
      addTag("act-" + tnum + "-tag-list")
      var btn = document.createElement("button");
      btn.setAttribute("type", "button");
      btn.setAttribute("class", "tag-add");
      btn.setAttribute("onclick", "addTag(\"act-" + tnum +
        "-tag-list\")");
      btn.appendChild(document.createTextNode("+"));
      row.appendChild(btn);

      inp_tsk.focus();
    }
