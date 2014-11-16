@ToDaMoonData = flight.component ->
  @after 'initialize', ->
    component = @

    join_room = (data) ->
      @.socket = new Phoenix.Socket(gon.config.chat_uri)

      @.socket.join "rooms", "lobby", data, (chan) =>

        chan.on 'notify:join', (d) ->
          if d.status == 'connected'
            component.trigger 'todamoon:notify:join'
            component.off document, 'todamoon:cmd:send'
            component.on document, 'todamoon:cmd:send', (event, message) ->
              chan.send('cmd:send', body: message.body)
          else if d.status == 'reconnected'
            component.trigger 'todamoon:notify:rejoin'
            chan.socket.close()
            chan.socket = null

        chan.on "user:enter", (d) ->
          component.trigger 'todamoon:user:enter', d

        chan.on "user:send", (d) ->
          component.trigger 'todamoon:user:send', d

        chan.on "user:limit_send", (d) ->
          component.trigger 'todamoon:user:limit_send', d

        chan.on "error:excessively_send", (d) ->
          component.trigger 'todamoon:error:excessively_send', d

        chan.on "error:limit_send", (d) ->
          component.trigger 'todamoon:error:limit_send', d

    if gon.current_user
      $.ajax
        type: "POST"
        url: "/todamoon/auth"
        success: (d) ->
          join_room(d)
    else
      join_room({})
