Redirect =
  archives: `<%= JSON.stringify(grunt.file.readJSON('json/archives.json')) %>`
  data:
    thread: {}
    post:   {}
    file:   {}

  init: ->
    for boardID, data of Conf['selectedArchives']
      for type, uid of data
        for archive in Conf['archives']
          continue if archive.uid isnt uid or type is 'post' and archive.software isnt 'foolfuuka'
          arr = if type is 'file'
            archive.files
          else
            archive.boards
          Redirect.data[type][boardID] = archive if boardID in arr
    for archive in Conf['archives']
      for boardID in archive.boards
        unless boardID of Redirect.data.thread
          Redirect.data.thread[boardID] = archive
        unless boardID of Redirect.data.post or archive.software isnt 'foolfuuka'
          Redirect.data.post[boardID] = archive
        unless boardID of Redirect.data.file or boardID not in archive.files
          Redirect.data.file[boardID] = archive

    Redirect.update()

  update: (cb) ->
    $.get 'lastarchivecheck', 0, ({lastarchivecheck}) ->
      now = Date.now()
      # Update the list of archives every 2 days.
      # The list is also updated when 4chan X gets updated.
      return if lastarchivecheck > now - 2 * $.DAY
      $.ajax '<%= meta.page %>json/archives.json', onload: ->
        return unless @status is 200
        Conf['archives'] = JSON.parse @response
        $.set
          lastarchivecheck: now
          archives: Conf['archives']
        cb? now

  to: (dest, data) ->
    archive = (if dest is 'search' then Redirect.data.thread else Redirect.data[dest])[data.boardID]
    return '' unless archive
    Redirect[dest] archive, data

  protocol: (archive) ->
    protocol = location.protocol
    unless archive[protocol[0...-1]]
      protocol = if protocol is 'https:' then 'http:' else 'https:'
    "#{protocol}//"

  thread: (archive, {boardID, threadID, postID}) ->
    # Keep the post number only if the location.hash was sent f.e.
    path = if threadID
      "#{boardID}/thread/#{threadID}"
    else
      "#{boardID}/post/#{postID}"
    if archive.software is 'foolfuuka'
      path += '/'
    if threadID and postID
      path += if archive.software is 'foolfuuka'
        "##{postID}"
      else
        "#p#{postID}"
    "#{Redirect.protocol archive}#{archive.domain}/#{path}"

  post: (archive, {boardID, postID}) ->
    # For fuuka-based archives:
    # https://github.com/eksopl/fuuka/issues/27
    URL = new String "#{Redirect.protocol archive}#{archive.domain}/_/api/chan/post/?board=#{boardID}&num=#{postID}"
    URL.archive = archive
    URL

  file: (archive, {boardID, filename}) ->
    "#{Redirect.protocol archive}#{archive.domain}/#{boardID}/full_image/#{filename}"

  search: (archive, {boardID, type, value}) ->
    type = if type is 'name'
      'username'
    else if type is 'MD5'
      'image'
    else
      type
    value = encodeURIComponent value
    path  = if archive.software is 'foolfuuka'
      "#{boardID}/search/#{type}/#{value}"
    else
      "#{boardID}/?task=search2&search_#{if type is 'image' then 'media_hash' else type}=#{value}"
    "#{Redirect.protocol archive}#{archive.domain}/#{path}"
