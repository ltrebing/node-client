{Base} = require './base'
log = require '../log'
{add_option_dict} = require './argparse'
{E} = require '../err'
{TrackSubSubCommand} = require '../tracksubsub'
{BufferInStream} = require('gpg-wrapper')
{master_ring} = require '../keyring'
{make_esc} = require 'iced-error'
{dict_union} = require '../util'
{User} = require '../user'
{env} = require '../env'

##=======================================================================

exports.Command = class Command extends Base

  #----------

  OPTS : dict_union TrackSubSubCommand.OPTS, {
    s:
      alias : "sign"
      action : "storeTrue"
      help : "sign in addition to encrypting"
    m:
      alias : "message"
      help : "provide the message on the command line"
    b :
      alias : 'binary'
      action: "storeTrue"
      help : "output in binary (rather than ASCII/armored)"
    o :
      alias : 'output'
      help : 'the output file to write the encryption to'
  }

  #----------

  add_subcommand_parser : (scp) ->
    opts = 
      aliases : [ "enc" ]
      help : "verify a user's authenticity and optionally track him"
    name = "encrypt"
    sub = scp.addParser name, opts
    add_option_dict sub, @OPTS
    sub.addArgument [ "them" ], { nargs : 1 , help : "the username of the receiver" }
    sub.addArgument [ "file" ], { nargs : '?', help : "the file to be encrypted" }
    return opts.aliases.concat [ name ]

  #----------

  do_encrypt : (cb) ->
    tp = @them.fingerprint true
    ti = @them.key_id_64()
    args = [ 
      "--encrypt", 
      "-r", tp,
      "--trusted-key", ti
    ]
    args.push( "--sign", "-u", (@tssc.me.fingerprint true) ) if @argv.sign
    gargs = { args }
    gargs.quiet = true
    args.push("--output", o, "--yes") if (o = @argv.output)
    args.push "-a"  unless @argv.binary
    if @argv.message
      gargs.stdin = new BufferInStream @argv.message 
    else if @argv.file?
      args.push @argv.file 
    else
      gargs.stdin = process.stdin
    await master_ring().gpg gargs, defer err, out
    unless @argv.output?
      log.console.log out.toString( if @argv.binary then 'utf8' else 'binary' )
    cb err 

  #----------

  run : (cb) ->
    esc = make_esc cb, "Command::run"
    batch = (not @argv.message and not @argv.file?)
    them_un = @argv.them[0]
    if them_un is env().get_username()
      await User.load_me esc defer @them
    else
      @tssc = new TrackSubSubCommand { args : { them : them_un }, opts : @argv, batch }
      await @tssc.run esc defer()
      @them = @tssc.them
    await @do_encrypt esc defer()
    cb null

##=======================================================================

