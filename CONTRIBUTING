Submitting patches
==================

Thank you for your interest in contributing to this project!

Please **do not** submit a pull request on GitHub.  The repository
there is an automated mirror, and I don't develop using GitHub's
platform.

Instead, either

- publish a branch somewhere (a GitHub fork is fine), and e-mail
  <spwhitton@spwhitton.name> asking me to merge your branch, possibly
  using git-request-pull(1)

- prepare patches with git-format-patch(1), and send them to
  <spwhitton@spwhitton.name>, probably using git-send-email(1)

You may find <https://git-send-email.io/> useful.

Reporting bugs
==============

Please use the CPAN bug tracker:
<https://rt.cpan.org/Public/Dist/Display.html?Name=Git-Annex>

Please read "How to Report Bugs Effectively" to ensure your bug report
constitutes a useful contribution to the project:
<https://www.chiark.greenend.org.uk/~sgtatham/bugs.html>

Signing off your commits
========================

Contributions are accepted upstream under the terms set out in the
file ``COPYING``.  You must certify the contents of the file
``DEVELOPER-CERTIFICATE`` for your contribution.  To do this, append a
``Signed-off-by`` line to end of your commit message.  An easy way to
add this line is to pass the ``-s`` option to git-commit(1).  Here is
an example of a ``Signed-off-by`` line:

::

    Signed-off-by: Sean Whitton <spwhitton@spwhitton.name>

Maintainance
============

Release process
---------------

1. Pull any updates to ``debian/`` from the Debian Perl Group's
   repository on salsa.debian.org

2. Ensure that the test suite passes under autopkgtest, so we can
   immediately upload the new release to Debian unstable:
   ``sbuild --dpkg-source-opts='-Zgzip -z1 --format=1.0 -sn'
   --run-autopkgtest``

3. ``dzil release``

4. Now proceed to update Debian unstable:

   1. ``git deborig``
   2. If it's not already present, add a new ``debian/changelog``
      entry with dch(1), or bump the version in an UNRELEASED entry
   3. sbuild etc.
   4. ``dgit push-source``
   5. Push master branch and all tags to both git.spwhitton.name and
      Debian Perl Team repo on salsa.debian.org.

Changelogs
----------

Be sure to record changes to the ``debian/`` directory in
``debian/changelog``, and changes to outside of the ``debian/``
directory in ``Changes``.

Git usage
---------

Avoid mixing changes to the ``debian/`` directory and changes to
outside of the ``debian/`` directory in the same commit.
