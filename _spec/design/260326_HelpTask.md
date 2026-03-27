# Progen Help Task 

## Background 

There is a pretty big 'mix namespace' around the 'mix hex.*' set of tasks.

The command 'mix hex' prints a nice help overview.

I'd like a task "mix progen" that prints a similar help overview for the 'progen' namespace.

    mix progen   # Prints ProGen help information 

    similar to "mix hex" 
    - print args for each task 
    - short documentation for each task 
    - divider lines between each task namespace 
    
      mix progen.action.___ 
      mix progen.action.___
      mix progen.action.___

      mix progen.validate.___
      mix progen.validate.___

## Directions 

Make the task 'self-assembling' - let it use introspection and dynamically
assemble the help page.  I don't want a hardcoded page that I have to
regenerate every time I tweak one of the progen mix tasks.
