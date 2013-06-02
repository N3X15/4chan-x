ThreadWatcher =
  init: ->
    return if !Conf['Thread Watcher']

    @db     = new DataBoard 'watchedThreads', @refresh, true
    @menu   = new UI.Menu 'thread watcher'
    @dialog = UI.dialog 'watcher', 'top: 50px; left: 0px;', """
    <%= grunt.file.read('html/Monitoring/ThreadWatcher.html').replace(/>\s+</g, '><').trim() %>
    """

    entry =
      type: 'thread watcher'
      el: $.el 'a',
        textContent: 'Open all threads'
        href: 'javascript:;'
      open: -> !!$.id('watched-threads').childElementCount
    $.event 'AddMenuEntry', entry
    $.on entry.el, 'click', ThreadWatcher.cb.openAll
    for key, val of Config.ThreadWatcher
      @addMenuEntry key, val[1]
    @addHeaderMenuEntry()

    $.on $('.menu-button', @dialog), 'click', @cb.menuToggle
    $.on d, 'QRPostSuccessful',   @cb.post
    $.on d, '4chanXInitFinished', @ready

    # XXX tmp conversion from old to new format
    $.get 'WatchedThreads', null, ({WatchedThreads}) ->
      return unless WatchedThreads
      for boardID, threads of ThreadWatcher.convert WatchedThreads
        for threadID, data of threads
          ThreadWatcher.db.set {boardID, threadID, val: data}
      $.delete 'WatchedThreads'

    Thread::callbacks.push
      name: 'Thread Watcher'
      cb:   @node

  node: ->
    toggler = $.el 'img',
      # XXX remove the favicon class in the future
      className: 'watcher-toggler favicon'
    $.on toggler, 'click', ThreadWatcher.cb.toggle
    $.before $('input', @OP.nodes.post), toggler

    return if g.VIEW isnt 'thread' or !Conf['Auto Watch']
    $.get 'AutoWatch', 0, ({AutoWatch}) =>
      return if AutoWatch isnt @ID
      ThreadWatcher.add @
      $.delete 'AutoWatch'

  addMenuEntry: (name, desc) ->
    entry =
      type: 'thread watcher'
      el: $.el 'label',
        innerHTML: "<input type=checkbox name='#{name}'> #{name}"
        title: desc
    $.event 'AddMenuEntry', entry
    input = entry.el.firstElementChild
    input.checked = Conf[name]
    $.on input, 'change', $.cb.checked
    $.on input, 'change', ThreadWatcher.refresh if name is 'Current Board'
  addHeaderMenuEntry: ->
    return if g.VIEW isnt 'thread'
    ThreadWatcher.entryEl = $.el 'a', href: 'javascript:;'
    entry =
      type: 'header'
      el: ThreadWatcher.entryEl
      order: 60
    $.event 'AddMenuEntry', entry
    $.on entry.el, 'click', -> ThreadWatcher.toggle g.threads["#{g.BOARD}.#{g.THREADID}"]

  ready: ->
    $.off d, '4chanXInitFinished', ThreadWatcher.ready
    return unless Main.isThisPageLegit()
    ThreadWatcher.refresh()
    $.add d.body, ThreadWatcher.dialog

  cb:
    menuToggle: (e) ->
      ThreadWatcher.menu.toggle e, @, ThreadWatcher
    openAll: ->
      for a in $$ 'a[title]', $.id 'watched-threads'
        $.open a.href
      return
    toggle: ->
      ThreadWatcher.toggle Get.postFromNode(@).thread
    rm: ->
      [boardID, threadID] = @parentNode.dataset.fullid.split '.'
      ThreadWatcher.rm boardID, +threadID
    post: (e) ->
      {board, postID, threadID} = e.detail
      if postID is threadID
        if Conf['Auto Watch']
          $.set 'AutoWatch', threadID
      else if Conf['Auto Watch Reply']
        ThreadWatcher.add board.threads[threadID]

  refresh: ->
    nodes = []
    for boardID, threads of ThreadWatcher.db.data.boards
      if Conf['Current Board'] and boardID isnt g.BOARD.ID
        continue
      for threadID, data of threads
        x = $.el 'a',
          textContent: '×'
          href: 'javascript:;'
        $.on x, 'click', ThreadWatcher.cb.rm
        link = $.el 'a',
          href: "/#{boardID}/res/#{threadID}"
          textContent: data.excerpt
          title: data.excerpt

        div = $.el 'div'
        div.setAttribute 'data-fullid', "#{boardID}.#{threadID}"
        $.add div, [x, $.tn(' '), link]
        nodes.push div

    list = ThreadWatcher.dialog.lastElementChild
    $.rmAll list
    $.add list, nodes

    if g.VIEW is 'thread'
      {entryEl} = ThreadWatcher
      if div = $ "div[data-fullid='#{g.BOARD}.#{g.THREADID}']", list
        $.addClass div, 'current'
        $.addClass entryEl, 'unwatch-thread'
        $.rmClass  entryEl, 'watch-thread'
        entryEl.textContent = 'Unwatch thread'
      else
        $.addClass entryEl, 'watch-thread'
        $.rmClass  entryEl, 'unwatch-thread'
        entryEl.textContent = 'Watch thread'

    for threadID, thread of g.BOARD.threads
      toggler = $ '.watcher-toggler', thread.OP.nodes.post
      toggler.src = if ThreadWatcher.db.get {boardID: thread.board.ID, threadID}
        Favicon.default
      else
        Favicon.empty
    return

  toggle: (thread) ->
    boardID  = thread.board.ID
    threadID = thread.ID
    if ThreadWatcher.db.get {boardID, threadID}
      ThreadWatcher.rm boardID, threadID
    else
      ThreadWatcher.add thread
  add: (thread) ->
    ThreadWatcher.db.set
      boardID:  thread.board.ID
      threadID: thread.ID
      val: excerpt: Get.threadExcerpt thread
    ThreadWatcher.refresh()
  rm: (boardID, threadID) ->
    ThreadWatcher.db.delete {boardID, threadID}
    ThreadWatcher.refresh()

  convert: (oldFormat) ->
    newFormat = {}
    for boardID, threads of oldFormat
      for threadID, data of threads
        (newFormat[boardID] or= {})[threadID] = excerpt: data.textContent
    newFormat
