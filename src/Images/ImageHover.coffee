ImageHover =
  init: ->
    if Conf['Image Hover']
      Post.callbacks.push
        name: 'Image Hover'
        cb:   @node
    if Conf['Image Hover in Catalog']
      CatalogThread.callbacks.push
        name: 'Image Hover'
        cb:   @catalogNode
  node: ->
    return unless @file?.isImage
    $.on @file.thumb, 'mouseover', ImageHover.mouseover
  catalogNode: ->
    return unless @thread.OP.file?.isImage
    $.on @nodes.thumb, 'mouseover', ImageHover.mouseover
  mouseover: (e) ->
    post = if $.hasClass @, 'thumb'
      g.posts[@parentNode.dataset.fullID]
    else
      Get.postFromNode @
    el = $.el 'img',
      id: 'ihover'
      src: post.file.URL
    el.dataset.fullID = post.fullID
    $.add d.body, el
    UI.hover
      root: @
      el: el
      latestEvent: e
      endEvents: 'mouseout click'
      asapTest: -> el.naturalHeight
    $.on el, 'error', ImageHover.error
  error: ->
    return unless doc.contains @
    post = g.posts[@dataset.fullID]

    src = @src.split '/'
    if src[2] is 'i.4cdn.org'
      URL = Redirect.to 'file',
        boardID:  src[3]
        filename: src[5].replace /\?.+$/, ''
      if URL
        @src = URL
        return
      if g.DEAD or post.isDead or post.file.isDead
        return

    timeoutID = setTimeout (=> @src = post.file.URL + '?' + Date.now()), 3000
    <% if (type === 'crx') { %>
    $.ajax post.file.URL,
      onloadend: ->
        return if @status isnt 404
        clearTimeout timeoutID
        post.kill true
    ,
      type: 'head'
    <% } else { %>
    # XXX CORS for i.4cdn.org WHEN?
    $.ajax "//a.4cdn.org/#{post.board}/res/#{post.thread}.json", onload: ->
      return if @status isnt 200
      for postObj in @response.posts
        break if postObj.no is post.ID
      if postObj.no isnt post.ID
        clearTimeout timeoutID
        post.kill()
      else if postObj.filedeleted
        clearTimeout timeoutID
        post.kill true
    <% } %>
