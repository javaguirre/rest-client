{$, ScrollView} = require 'atom-space-pen-views'
querystring = require 'querystring'

RestClientResponse = require './rest-client-response'
RestClientEditor = require './rest-client-editor'
RestClientHttp = require './rest-client-http'

ENTER_KEY = 13
CURRENT_METHOD = 'GET'
DEFAULT_NORESPONSE = 'NO RESPONSE'

response = '' # global object for the response.

rest_form =
  url: '.rest-client-url',
  method: '.rest-client-method',
  method_other_field: '.rest-client-method-other-field',
  headers: '.rest-client-headers',
  payload: '.rest-client-payload',
  encode_payload: '.rest-client-encodepayload',
  decode_payload: '.rest-client-decodepayload',
  content_type: '.rest-client-content-type',
  load_btn: '.rest-config-load',
  save_btn: '.rest-config-save',
  clear_btn: '.rest-client-clear',
  send_btn: '.rest-client-send',
  result: '.rest-client-result',
  status: '.rest-client-status',
  user_agent: '.rest-client-user-agent',
  open_in_editor: '.rest-client-open-in-editor'
  loading: '.rest-client-loading-icon'


module.exports =
class RestClientView extends ScrollView
  @content: ->
    @div class: 'rest-client native-key-bindings padded pane-item', tabindex: -1, =>
      @div class: 'rest-client-url-container', =>
        # Clear / Send
        @div class: 'block rest-client-action-btns', =>
          @div class: 'block', =>
            @div class: 'btn-group btn-group-lg', =>
              @button class: "btn btn-lg #{rest_form.load_btn.split('.')[1]}", 'Load'
              @button class: "btn btn-lg #{rest_form.save_btn.split('.')[1]}", 'Save'
              @button class: "btn btn-lg #{rest_form.clear_btn.split('.')[1]}", 'Clear'
              @button class: "btn btn-lg #{rest_form.send_btn.split('.')[1]}", 'Send'

        @input type: 'text', class: "field native-key-bindings #{rest_form.url.split('.')[1]}", autofocus: 'true'

        # methods
        ## GET
        @div class: 'btn-group btn-group-sm rest-client-methods', =>
          for method in RestClientHttp.METHODS
            if method is 'get'
              @button class: "btn selected #{rest_form.method.split('.')[1]}-#{method}", method.toUpperCase()
            else
              @button class: "btn #{rest_form.method.split('.')[1]}-#{method}", method.toUpperCase()

        # Headers
        @div class: 'rest-client-headers-container', =>
          @h5 'Headers'

          @div class: 'btn-group btn-group-lg', =>
            @button class: 'btn selected', 'Raw'

          @textarea class: "field native-key-bindings #{rest_form.headers.split('.')[1]}", rows: 7
          @strong 'User-Agent'
          @input class: "field #{rest_form.user_agent.split('.')[1]}", value: 'atom-rest-client'

        # Payload
        @div class: 'rest-client-payload-container', =>
          @h5 'Payload'

          @div class: "text-info lnk float-right #{rest_form.decode_payload.split('.')[1]}", 'Decode payload '
          @div class: "text-info lnk float-right #{rest_form.encode_payload.split('.')[1]}", 'Encode payload'
          @div class: 'btn-group btn-group-lg', =>
            @button class: 'btn selected', 'Raw'

          @textarea class: "field native-key-bindings #{rest_form.payload.split('.')[1]}", rows: 7

        # Content-Type
        @select class: "list-group #{rest_form.content_type.split('.')[1]}", =>
          @option class: 'selected', 'application/x-www-form-urlencoded', 'application/x-www-form-urlencoded'
          @option value: 'application/atom+xml', 'application/atom+xml'
          @option value: 'application/json', 'application/json'
          @option value:'application/xml', 'application/xml'
          @option value: 'application/multipart-formdata', 'application/multipart-formdata'
          @option value: 'text/html', 'text/html'
          @option value: 'text/plain', 'text/plain'

        # Result
        @div class: 'tool-panel panel-bottom padded', =>
          @strong 'Result | '
          @span class: "#{rest_form.status.split('.')[1]}"

          @span class: "#{rest_form.loading.split('.')[1]} loading loading-spinner-small inline-block", style: 'display: none;'
          @pre class: "native-key-bindings #{rest_form.result.split('.')[1]}", "#{RestClientResponse.DEFAULT_RESPONSE}"
          @div class: "text-info lnk #{rest_form.open_in_editor.split('.')[1]}", 'Open in separate editor'

  initialize: ->
    for method in RestClientHttp.METHODS
      @on 'click', "#{rest_form.method}-#{method}", ->
        $('.rest-client-methods').children().removeClass('selected')
        $(this).addClass('selected')
        CURRENT_METHOD = $(this).html()

    @on 'click', rest_form.load_btn, => @loadFile()
    @on 'click', rest_form.save_btn, => @saveFile()

    @on 'click', rest_form.clear_btn, => @clearForm()
    @on 'click', rest_form.send_btn,  => @sendRequest()

    @on 'click', rest_form.encode_payload, => @encodePayload()
    @on 'click', rest_form.decode_payload, => @decodePayload()

    @on 'click', rest_form.open_in_editor, => @openInEditor()

    @on 'keypress', rest_form.url, ((_this) ->
      ->
        _this.sendRequest()  if event.keyCode is ENTER_KEY
        return
    )(this)

  openInEditor: ->
    textResult = $(rest_form.result).text()
    file_name = "#{CURRENT_METHOD} - #{$(rest_form.url).val()}"
    editor = new RestClientEditor(textResult, file_name)
    editor.open()

  encodePayload: ->
    $(rest_form.payload).val(
      RestClientHttp.encodePayload($(rest_form.payload).val())
    )

  decodePayload: ->
    $(rest_form.payload).val(
      RestClientHttp.decodePayload($(rest_form.payload).val())
    )

  loadFile: ->
    response = dialog.showOpenDialog({properties:['openFile']})

    if response == undefined
      return

    fs.readFile(response[0], (err, data) ->

      if err
        atom.confirm(
            message: 'Cannot load file' + file_path,
            detailedMessage: JSON.stringify(err)
        )
        return

      try
        jsonResponse = JSON.parse(data)

        f_url = jsonResponse.url
        f_header = jsonResponse.headers
        f_user_agent = jsonResponse.user_agent
        f_payload = jsonResponse.payload
      catch err2
        atom.confirm(
          message: 'Cannot parse file' + file_path,
          detailedMessage: JSON.stringify(err2)
        )
        return

      $(rest_form.url).val(f_url)
      $(rest_form.headers).val(f_header)
      $(rest_form.user_agent).val(f_user_agent)
      $(rest_form.payload).val(f_payload)
    )

  saveFile: ->
    file_path = dialog.showSaveDialog({properties:['saveFile']})
    outval = {
      'url':$(rest_form.url).val(),
      'headers':$(rest_form.headers).val(),
      'user_agent':$(rest_form.user_agent).val(),
      'payload': $(rest_form.payload).val()
      };

    fs.writeFile("#{file_path}", JSON.stringify(outval), (err) ->
      if err
        atom.confirm(
          message: 'Cannot save file' + file_path,
          detailedMessage: JSON.stringify(err)
        )
      )

  clearForm: ->
    @hideLoading()
    $(rest_form.result).show()
    $(rest_form.url).val("")
    $(rest_form.headers).val("")
    $(rest_form.payload).val("")
    $(rest_form.result).text(RestClientResponse.DEFAULT_RESPONSE)
    $(rest_form.status).text("")

  getHeaders: ->
    headers = {
      'User-Agent': $(rest_form.user_agent).val(),
      'Content-Type': $(rest_form.content_type).val() + ';charset=utf-8'
    }
    custom_headers = $(rest_form.headers).val().split('\n')

    for custom_header in custom_headers
      current_header = custom_header.split(':')
      if current_header.length > 1
        headers[current_header[0]] = current_header[1].trim()

    return headers

  sendRequest: ->
    request_options =
      url: $(rest_form.url).val()
      headers: this.getHeaders()
      method: CURRENT_METHOD,
      body: @getRequestBody()

    @showLoading()
    RestClientHttp.send(request_options, @onResponse)

  onResponse: (error, response, body) =>
    if !error
      switch response.statusCode
        when 200,201,204
          @showSuccessfulResponse(response.statusCode + " " + response.statusMessage)
        else
          @showErrorResponse(response.statusCode + " " +response.statusMessage)

      response = new RestClientResponse(body).getFormatted()
      $(rest_form.result).text(response)
      @hideLoading()
    else
      @showErrorResponse(DEFAULT_NORESPONSE)
      $(rest_form.result).text(error)
      @hideLoading()

  getRequestBody: ->
    payload = $(rest_form.payload).val()
    body = ""

    if payload
      switch $(rest_form.content_type).val()
        when "application/json"
          json_obj = JSON.parse(payload)
          body = JSON.stringify(json_obj)
        else
          body = payload

    body

  showSuccessfulResponse: (text) =>
    $(rest_form.status)
      .removeClass('text-error')
      .addClass('text-success')
      .text(text)

  showErrorResponse: (text) =>
    $(rest_form.status)
      .removeClass('text-success')
      .addClass('text-error')
      .text(text)

  # Returns an object that can be retrieved when package is activated
  serialize: ->
    deserializer: @constructor.name
    uri: @getUri()

  getUri: -> @uri

  getTitle: -> "REST Client"

  getModel: ->

  # loading bar
  showLoading: ->
    $(rest_form.result).hide()
    $(rest_form.loading).show()

  hideLoading: ->
    $(rest_form.loading).fadeOut()
    $(rest_form.result).show()
