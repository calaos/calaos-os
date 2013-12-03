BEGIN {
	FS =",";
 }

$1 !~ "^#" { system("./scripts/layerman " $1 " "  $2 " " $3 " " $4 " " command " " commandarg);}
