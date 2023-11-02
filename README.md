Mocap-BVH version 0.01
======================

# NAME

Mocap::BVH - Perl extension for editing BVH files

# INSTALLATION

To install this module run following:
```
perl Makefile.PL
make
make test
make install
```

# SYNOPSIS

```
use Mocap::BVH;
$bvh = Mocap::BVH->load('file.bvh');    # load a BVH file
$root = $bvh->root; # get root joint
$neck = $bvh->joint('neck');        # get the joint name "neck"
@joints = $bvh->joints; # get all joints
for (@joints) {
    print $_->name; # print joint name
}
$neck->name('Neck');    # change joint name
$bvh->save('modified-file.bvh');    # save the file
```

# DESCRIPTION

    This package is for loading, editing, and saving BVH files. You can
    modify the joint propertis such as "name" and "offset", change channel
    values in different frames, and modify the skeleton structure (see
    Mocap::BVH::Joint for details).

# COPYRIGHT AND LICENCE

Copyright (C) 2019 by Kaixiang Xie

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.28.1 or,
at your option, any later version of Perl 5 you may have available.

