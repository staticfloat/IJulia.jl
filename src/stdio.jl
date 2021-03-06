# During handling of an execute_request (when execute_msg is !nothing),
# we redirect STDOUT and STDERR into "stream" messages sent to the IPython
# front-end.

const orig_STDOUT = STDOUT
const orig_STDERR = STDERR

# logging in verbose mode goes to original stdio streams.  Use macros
# so that we do not even evaluate the arguments in no-verbose modes
macro vprintln(x...)
    quote
        if verbose::Bool
            println(orig_STDOUT, $(x...))
        end
    end
end
macro verror_show(e, bt)
    quote
        if verbose::Bool
            Base.error_show(orig_STDERR, $e, $bt)
        end
    end
end

function send_stream(s::String, name::String)
    if !isempty(s)
        send_ipython(publish,
                     msg_pub(execute_msg, "stream",
                             ["name" => name, "data" => s]))
    end
end

function watch_stream(rd::IO, name::String)
    try
        while true
            s = readavailable(rd) # blocks until something available
	    send_stream(s, name)
            sleep(0.1) # a little delay to accumulate output
        end
    catch e
        # the IPython manager may send us a SIGINT if the user
        # chooses to interrupt the kernel; don't crash on this
        if isa(e, InterruptException)
            watch_stream(rd, name)
        else
            rethrow()
        end
    end
end

const read_stdout, write_stdout = redirect_stdout()
const read_stderr, write_stderr = redirect_stderr()

function watch_stdio()
    @async watch_stream(read_stdout, "stdout")
    @async watch_stream(read_stderr, "stderr")
end
