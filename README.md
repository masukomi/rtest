## RTest 

An RSpec wrapper that cuts down on the noisy output,
and makes it easier to re-run failing tests.

### Why Use It? 
I'll answer that with 2 pictures. I've added 5 failures into the multipart-post gem and then run the full test suite. The 1st image is `rspec`'s output. The 2nd image is `rtest`'s output. It's still running the same `rspec`, it's just trimming the fat from the output and making it more readable and clear. 

#### RSpec output
![example rspec output](https://github.com/masukomi/rtest/blob/example_images/docs/images/example_rspec_output.png?raw=true)  

#### rtest output
This is `rtest`'s output for the exact same `rspec` run.

![example rtest output](https://github.com/masukomi/rtest/blob/example_images/docs/images/example_rtest_output.png?raw=true)



Things you can do with RTest:

* easily see the line of code that failed and the line of your spec that failed.
  - more focused test output
  - radically more focused test output
  - no more wading through hundreds of lines of stuff that doesn't
    help you.
* quickly see a numbered list of what failed on your last run
  - `rtest`
* trivially rerun a past failure
  - `rtest <n>` where `n` is the number of the failed test
* trivially rerun all the past failures (and nothing else)
  - `rtest rerun`
* get a list of files that contained failing tests
  - `rtest files`
* get the path to the file that contained a specific failure
  - `rtest file <n>` where `n` is the number of the failed test.

Run `rtest --help` for all the options.
 
## Installation 

### macOS with Homebrew

```
brew tap masukomi/homebrew-apps
brew install rtest
```

### everything else
Clone this repo.  
Add the `rtest` executable to your path.


## Usage

To start the process you invoke rtest in one of the following ways:

* `rtest path/to/spec.rb` 
* `rtest directory/of/tests` 
* `rtest all`

The first two work in exactly the same way as `rspec`. The last one just runs `bundle exec rspec` with no parameters, to invoke _all_ of your tests.

`rtest` will give you the summarized output with each test numbered. After that you can run `rtest <n>` to rerun a specific failed test. Or, run `rtest` with no arguments to see the full list of failures and their details. This happens immediately, without rerunning the tests. 

Run `rtest --help` to see the full list of available commands.

## Notes
To do its job `rtest` creates a hidden file in the current directory named `.rtest.json` which contains the relevant information from whatever RSpec tests you had it run last. 

The line numbers of failed tests are the lines they were, when it ran, but you're probably about to change that as you fix them, and reruning the old line number could cause the wrong test to be run, or maybe multiple tests. To compensate for this, and still just run 1 specific failed test you can give `rtest` the offset. For example, let's say you're working on failure # 3 and your changes moved the test down 5 lines. You'd say `rtest 3 +5` If it was 5 lines higher you'd say `rtest 3 -5` Alternately you just start the process over by invoking it with a specific path or running `rtest all` if you want to run _all_ available tests.

