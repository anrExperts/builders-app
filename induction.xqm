xquery version "3.0";
module namespace xpr.xpr = "xpr.xpr";
(:~
 : This xquery module is an application for xpr — builders
 :
 : @author sardinecan (ANR Experts)
 : @since 2022-06
 : @licence GNU http://www.gnu.org/licenses
 : @version 0.2
 :
 : builders is free software: you can redistribute it and/or modify
 : it under the terms of the GNU General Public License as published by
 : the Free Software Foundation, either version 3 of the License, or
 : (at your option) any later version.
 :
 :)

import module namespace Session = 'http://basex.org/modules/session';
import module namespace functx = "http://www.functx.com";

declare namespace rest = "http://exquery.org/ns/restxq" ;
declare namespace file = "http://expath.org/ns/file" ;
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization" ;
declare namespace db = "http://basex.org/modules/db" ;
declare namespace web = "http://basex.org/modules/web" ;
declare namespace update = "http://basex.org/modules/update" ;
declare namespace perm = "http://basex.org/modules/perm" ;
declare namespace user = "http://basex.org/modules/user" ;
declare namespace session = 'http://basex.org/modules/session' ;

declare namespace ev = "http://www.w3.org/2001/xml-events" ;

declare namespace map = "http://www.w3.org/2005/xpath-functions/map" ;
declare namespace xf = "http://www.w3.org/2002/xforms" ;
declare namespace xlink = "http://www.w3.org/1999/xlink" ;

declare namespace xpr = "xpr" ;
declare default element namespace "xpr" ;
declare default function namespace "xpr.xpr" ;

declare default collation "http://basex.org/collation?lang=fr" ;

declare variable $xpr.xpr:xsltFormsPath := "/builders/files/xsltforms/xsltforms.xsl" ;
declare variable $xpr.xpr:home := file:base-dir() ;

(:~
 : this function defines a static files directory for the app
 :
 : @param $file file or unknown path
 : @return binary file
 :)
declare
  %rest:path('builders/files/{$file=.+}')
function xpr.xpr:file($file as xs:string) as item()+ {
  let $path := file:base-dir() || 'files/' || $file
  return
    (
      web:response-header( map {'media-type' : web:content-type($path)}),
      file:read-binary($path)
    )
};

(:~
 : This resource function defines the application root
 : @return redirect to the home page or to the install
 :)
declare
  %rest:path("/builders")
  %output:method("xml")
function index() {
  if (db:exists("builders"))
    then web:redirect("/builders/inductions/view")
    else web:redirect("/builders/install")
};

(:~
 : This resource function install
 : @return create the db
 :)
declare
  %rest:path("/builders/install")
  %output:method("xml")
  %updating
function buildersInstall() {
  if (db:exists("builders"))
    then (
      update:output("La base « builders » existe déjà !")
     )
    else (
      update:output("La base « builders » a été créée"),
      db:create( "builders", <builders><inductions/></builders>, "builders.xml", map {"chop" : fn:false()} )
      )
};

(:~
 : This resource function lists all the inductions
 : @return an ordered list of inductions in xml
 :)
declare
  %rest:path("/builders/inductions")
  %rest:produces('application/xml')
  %output:method("xml")
function getInductions() {
  db:open('builders')/builders/inductions
};

(:~
 : This resource function lists all the induction
 : @return an ordered list of inductions in html
 :)
declare
  %rest:path("/builders/inductions/view")
  %rest:produces('application/xml')
  %output:method("html")
function getInductionsHTML() {
  <html>
    <head>
      <title>xpr - Builders app</title>
      <meta charset="UTF-8"/>
    </head>
    <body>
      <h1>xpr — Builders App</h1>
      <p>{
        if(Session:get('id')!='') then ('Bienvenue ' || Session:get('id') || ' ', <a href="/builders/logout">se déconnecter</a>)
        else <a href="/builders/login">se connecter</a>
      }</p>

      {
        let $inductions := db:open('builders')/builders/inductions
        return
          if(fn:normalize-space($inductions) = '') then
            <p>Aucune réception. <a href="/builders/inductions/new">Accéder au formulaire</a></p>
          else(
            <h2>Liste des réceptions à la maîtrise</h2>,
            <ul>{
              for $induction in $inductions/induction
              return
                <li>{
                  "Réception de "
                  || $induction/description/candidate/persName/fn:string-join((fn:normalize-space(surname), fn:normalize-space(forename)), ', ')
                  || ' ',
                  if(Session:get('id') and user:list-details(Session:get('id'))/*:info/*:grant/@type = 'inductions' and user:list-details(Session:get('id'))/*:database[@pattern='builders']/@permission = 'write') then
                  <a href="/builders/inductions/{fn:normalize-space($induction/@xml:id)}/modify">modifier</a>
                }</li>
            }</ul>
          )


      }
    </body>
  </html>

};

(:~
 : This resource function edits a new induction
 : @return an xforms to edit an induction
:)
declare
  %rest:path("builders/inductions/new")
  %output:method("xml")
  %perm:allow("inductions")
function newInduction() {
  let $content := map {
    'instance' : '',
    'model' : ('xprExpertiseModel.xml', 'xprAutosaveModel.xml'),
    'trigger' : 'xprExpertiseTrigger.xml',
    'form' : 'xprExpertiseForm.xml'
  }
  let $outputParam := map {
    'layout' : "template.xml"
  }
  return
    (processing-instruction xml-stylesheet { fn:concat("href='", $xpr.xpr:xsltFormsPath, "'"), "type='text/xsl'"},
    <?css-conversion no?>,
    fn:doc('files/index.xml')
    )
};

(:~
 : This resource function modify an induction item
 : @param $id the induction id
 : @return an induction in xml
 :)
declare
  %rest:path("builders/inductions/{$id}")
  %output:method("xml")
function getInduction($id) {
  db:open('builders')/builders/inductions/induction[@xml:id=$id]
};

(:~
 : This resource function modify an induction item
 : @param $id the induction id
 : @return an xforms to edit the induction
 :)
declare
  %rest:path("builders/inductions/{$id}/modify")
  %output:method("xml")
  %perm:allow("inductions")
function modifyInduction($id) {
  let $form := fn:doc('files/index.xml')
  let $instance := '/builders/inductions/' || $id
  let $updatedForm :=
  copy $d := $form
    modify (
      replace value of node $d//*:instance[@id='induction']/@src with $instance
    )
    return $d
  return(
    processing-instruction xml-stylesheet { fn:concat("href='", $xpr.xpr:xsltFormsPath, "'"), "type='text/xsl'"},
    <?css-conversion no?>,
    $updatedForm
  )
};

(:~
 : This function creates new inductions
 : @param $param content to insert in the database
 : @param $refere the callback url
 : @return update the database with an updated content and an 200 http
 :)
declare
  %rest:path("builders/inductions/put")
  %output:method("xml")
  %rest:header-param("Referer", "{$referer}", "none")
  %rest:PUT("{$param}")
  %perm:allow("expertises", "write")
  %updating
function putInduction($param, $referer) {
  let $db := db:open("builders")
  let $user := fn:normalize-space(user:list-details(Session:get('id'))/@name)
  return
    if (fn:ends-with($referer, 'modify'))
    then
      let $location := fn:analyze-string($referer, 'builders/inductions/(.+?)/modify')//fn:group[@nr='1']
      let $param := $param

      return (
        replace node $db/builders/inductions/induction[@xml:id = $location] with $param,
        update:output(
         (
          <rest:response>
            <http:response status="200" message="test">
              <http:header name="Content-Language" value="fr"/>
              <http:header name="Content-Type" value="text/plain; charset=utf-8"/>
            </http:response>
          </rest:response>,
          <result>
            <id>{$location}</id>
            <message>La ressource a été modifiée.</message>
            <url></url>
          </result>
         )
        )
      )
    else
      let $id := fn:generate-id($param)
      let $param :=
        copy $d := $param
        modify (
          insert node attribute xml:id {$id} into $d/*
        )
        return $d
      return (
        insert node $param into $db/builders/inductions,
        update:output(
         (
          <rest:response>
            <http:response status="200" message="test">
              <http:header name="Content-Language" value="fr"/>
            </http:response>
          </rest:response>,
          <result>
            <id>{$id}</id>
            <message>La ressource a été créée.</message>
            <url></url>
          </result>
         )
        )
      )
};

(:~
 : Permissions: inductions
 : Checks if the current user is granted; if not, redirects to the login page.
 : @param $perm map with permission data
 :)
declare
    %perm:check('builders/inductions', '{$perm}')
function permInduction($perm) {
  let $user := Session:get('id')
  return
    if((fn:empty($user) or fn:not(user:list-details($user)/*:info/*:grant/@type = $perm?allow)) and fn:ends-with($perm?path, 'new'))
      then web:redirect('/builders/login/')
    else if((fn:empty($user) or fn:not(user:list-details($user)/*:info/*:grant/@type = $perm?allow)) and fn:ends-with($perm?path, 'modify'))
      then web:redirect('/builders/login')
    else if((fn:empty($user) or fn:not(user:list-details($user)/*:info/*:grant/@type = $perm?allow[1] and user:list-details($user)/*:database[@pattern='builders']/@permission = $perm?allow[2])) and fn:ends-with($perm?path, 'put'))
      then web:redirect('/builders/login')
};

(:~ Login page (visible to everyone). :)
declare
  %rest:path("builders/login")
  %output:method("html")
function login() {
  <html>
    Please log in:
    <form action="/builders/login/check" method="post">
      <input name="name"/>
      <input type="password" name="pass"/>
      <input type="submit"/>
    </form>
  </html>
};

declare
  %rest:path("builders/login/check")
  %rest:query-param("name", "{$name}")
  %rest:query-param("pass", "{$pass}")
function login($name, $pass) {
  try {
    user:check($name, $pass),
    Session:set('id', $name),
    web:redirect("/builders/inductions/view")
  } catch user:* {
    web:redirect("/builders/inductions/view")
  }
};

declare
  %rest:path("builders/logout")
function logout() {
  Session:delete('id'),
  web:redirect("/builders/inductions/view")
};