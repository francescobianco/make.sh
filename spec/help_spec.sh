Describe 'help command:'
  Include src/main.sh

  Describe '--help no arguments'
    It 'match with make --help'
      When call main --help
      The output should eq "$(make --help)"
    End
  End
End
